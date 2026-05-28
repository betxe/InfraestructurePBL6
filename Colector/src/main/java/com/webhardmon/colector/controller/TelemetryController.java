package com.webhardmon.colector.controller;

import com.webhardmon.colector.dto.TelemetryPayload;
import com.webhardmon.colector.service.KafkaProducerService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

/**
 * Endpoint REST que recibe los payloads de telemetría de los agentes de hardware.
 * El tráfico llega desde los agentes a través del Cloudflare Tunnel.
 */
@RestController
@RequestMapping("/api/v1")
public class TelemetryController {

    private static final Logger log = LoggerFactory.getLogger(TelemetryController.class);

    private final KafkaProducerService kafkaProducerService;

    public TelemetryController(KafkaProducerService kafkaProducerService) {
        this.kafkaProducerService = kafkaProducerService;
    }

    /**
     * Recibe un payload de telemetría, lo valida y lo publica en Kafka.
     *
     * POST /api/v1/telemetry
     *
     * Body:
     * {
     *   "agent_id": "server-01",
     *   "timestamp": 1716890000,
     *   "metrics": {
     *     "cpu_usage": 42.5,
     *     "ram_used_mb": 8192,
     *     "disk_io_mb": 120
     *   }
     * }
     *
     * Responde 202 Accepted — el dato se ha encolado en Kafka, no procesado sincrónicamente.
     */
    @PostMapping("/telemetry")
    public ResponseEntity<Map<String, Object>> ingestTelemetry(
            @Valid @RequestBody TelemetryPayload payload) {

        log.info("Recibida telemetría del agente '{}' con {} métricas",
                payload.getAgent_id(), payload.getMetrics().size());

        kafkaProducerService.publish(payload);

        return ResponseEntity.status(HttpStatus.ACCEPTED).body(Map.of(
                "status", "accepted",
                "agent_id", payload.getAgent_id(),
                "received_at", Instant.now().toString()
        ));
    }

    /**
     * Health check simple (complementa el de Spring Actuator).
     * Útil para verificar que el controlador responde correctamente.
     *
     * GET /api/v1/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP", "service", "colector"));
    }
}
