package com.webhardmon.colector.controller;

import com.webhardmon.colector.service.KafkaProducerService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

/**
 * Endpoint REST que recibe payloads de telemetría Avro binarios de los agentes
 * de hardware y los reenvía intactos a Kafka (pass-through).
 *
 * El Colector NO deserializa el contenido Avro. La resolución del schema
 * se delega al Java Cluster, que consulta el Schema Registry al consumir.
 *
 * Protocolo esperado del agente:
 *   POST /api/v1/telemetry
 *   Content-Type: application/octet-stream
 *   X-Agent-Id: server-01
 *   Body: <bytes Avro en Confluent wire format: 0x00 + schema_id(4B) + avro_payload>
 */
@RestController
@RequestMapping("/api/v1")
public class TelemetryController {

    private static final Logger log = LoggerFactory.getLogger(TelemetryController.class);

    /** Header que identifica al agente. Se usa como clave Kafka para garantizar
     *  ordenación por agente en la misma partición. */
    private static final String HEADER_AGENT_ID = "X-Agent-Id";

    private final KafkaProducerService kafkaProducerService;

    public TelemetryController(KafkaProducerService kafkaProducerService) {
        this.kafkaProducerService = kafkaProducerService;
    }

    /**
     * Recibe un payload Avro binario y lo publica en Kafka sin modificarlo.
     *
     * @param agentId   Header X-Agent-Id — identifica al agente origen
     * @param avroBytes Cuerpo binario: Avro serializado en Confluent wire format
     * @return 202 Accepted si el mensaje fue encolado correctamente
     * @return 400 Bad Request si falta el header X-Agent-Id o el body está vacío
     */
    @PostMapping(
            value = "/telemetry",
            consumes = MediaType.APPLICATION_OCTET_STREAM_VALUE
    )
    public ResponseEntity<Map<String, Object>> ingestTelemetry(
            @RequestHeader(value = HEADER_AGENT_ID, required = false) String agentId,
            @RequestBody byte[] avroBytes) {

        // Validaciones mínimas — no tocamos el contenido binario
        if (agentId == null || agentId.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "error",
                    "code", "MISSING_AGENT_ID",
                    "message", "El header '" + HEADER_AGENT_ID + "' es obligatorio"
            ));
        }

        if (avroBytes == null || avroBytes.length == 0) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "error",
                    "code", "EMPTY_PAYLOAD",
                    "message", "El cuerpo del mensaje no puede estar vacío"
            ));
        }

        log.info("Recibida telemetría [agente='{}', bytes={}]", agentId, avroBytes.length);

        kafkaProducerService.publish(agentId, avroBytes);

        return ResponseEntity.status(HttpStatus.ACCEPTED).body(Map.of(
                "status", "accepted",
                "agent_id", agentId,
                "bytes", avroBytes.length,
                "received_at", Instant.now().toString()
        ));
    }

    /**
     * Health check simple. Complementa el endpoint de Spring Actuator.
     * GET /api/v1/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP", "service", "colector"));
    }
}
