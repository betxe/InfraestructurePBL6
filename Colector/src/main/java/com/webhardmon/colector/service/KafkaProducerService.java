package com.webhardmon.colector.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.webhardmon.colector.dto.TelemetryPayload;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

/**
 * Servicio responsable de serializar y publicar los payloads de telemetría
 * en el topic de Kafka correspondiente.
 */
@Service
public class KafkaProducerService {

    private static final Logger log = LoggerFactory.getLogger(KafkaProducerService.class);

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;

    @Value("${webhardmon.kafka.topic:raw-telemetry}")
    private String topic;

    public KafkaProducerService(KafkaTemplate<String, String> kafkaTemplate,
                                ObjectMapper objectMapper) {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
    }

    /**
     * Publica un payload de telemetría en Kafka.
     * La clave del mensaje es el agent_id, lo que garantiza que todos los
     * mensajes del mismo agente van a la misma partición (orden garantizado).
     *
     * @param payload El objeto de telemetría validado
     */
    public void publish(TelemetryPayload payload) {
        String json;
        try {
            json = objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException e) {
            log.error("Error serializando el payload del agente {}: {}",
                    payload.getAgent_id(), e.getMessage());
            throw new RuntimeException("Error serializando el payload", e);
        }

        CompletableFuture<SendResult<String, String>> future =
                kafkaTemplate.send(topic, payload.getAgent_id(), json);

        future.whenComplete((result, ex) -> {
            if (ex != null) {
                log.error("Error publicando en Kafka [agente={}]: {}",
                        payload.getAgent_id(), ex.getMessage());
            } else {
                log.debug("Publicado en Kafka [topic={}, partition={}, offset={}, agente={}]",
                        result.getRecordMetadata().topic(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset(),
                        payload.getAgent_id());
            }
        });
    }
}
