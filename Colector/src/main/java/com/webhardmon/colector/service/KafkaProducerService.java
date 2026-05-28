package com.webhardmon.colector.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

/**
 * Publica mensajes Avro binarios en Kafka sin deserializarlos.
 *
 * El Colector actúa como pass-through: recibe los bytes exactos que el agente
 * serializó con Avro + Schema Registry y los reenvía intactos al topic de Kafka.
 * La desserialización y la consulta al Schema Registry se realiza aguas abajo
 * en el Java Cluster.
 *
 * Formato del mensaje en Kafka (Confluent wire format):
 *   [0x00][schema_id 4 bytes][avro payload]
 */
@Service
public class KafkaProducerService {

    private static final Logger log = LoggerFactory.getLogger(KafkaProducerService.class);

    // KafkaTemplate parametrizado con byte[] para no tocar el payload Avro
    private final KafkaTemplate<String, byte[]> kafkaTemplate;

    @Value("${webhardmon.kafka.topic:raw-telemetry}")
    private String topic;

    public KafkaProducerService(KafkaTemplate<String, byte[]> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    /**
     * Publica los bytes Avro en Kafka.
     *
     * La clave del mensaje es el agentId, lo que garantiza que todos los
     * mensajes del mismo agente van a la misma partición (orden garantizado
     * por agente, necesario para el procesamiento en el Java Cluster).
     *
     * @param agentId  Identificador del agente, extraído del header HTTP X-Agent-Id
     * @param avroBytes Payload Avro binario tal cual lo envió el agente
     */
    public void publish(String agentId, byte[] avroBytes) {
        CompletableFuture<SendResult<String, byte[]>> future =
                kafkaTemplate.send(topic, agentId, avroBytes);

        future.whenComplete((result, ex) -> {
            if (ex != null) {
                log.error("Error publicando en Kafka [agente={}, bytes={}]: {}",
                        agentId, avroBytes.length, ex.getMessage());
            } else {
                log.debug("Publicado en Kafka [topic={}, partition={}, offset={}, agente={}, bytes={}]",
                        result.getRecordMetadata().topic(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset(),
                        agentId,
                        avroBytes.length);
            }
        });
    }
}
