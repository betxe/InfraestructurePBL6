package com.webhardmon.colector.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.util.Map;

/**
 * Payload de telemetría enviado por los agentes de hardware.
 *
 * Ejemplo de request:
 * {
 *   "agent_id": "server-01",
 *   "timestamp": 1716890000,
 *   "metrics": {
 *     "cpu_usage": 42.5,
 *     "ram_used_mb": 8192,
 *     "disk_io_mb": 120
 *   }
 * }
 */
public class TelemetryPayload {

    @NotBlank(message = "agent_id es obligatorio")
    private String agent_id;

    @NotNull(message = "timestamp es obligatorio")
    @Positive(message = "timestamp debe ser un Unix epoch positivo")
    private Long timestamp;

    @NotNull(message = "metrics es obligatorio")
    private Map<String, Object> metrics;

    // ── Getters & Setters ─────────────────────────────────────────────────

    public String getAgent_id() { return agent_id; }
    public void setAgent_id(String agent_id) { this.agent_id = agent_id; }

    public Long getTimestamp() { return timestamp; }
    public void setTimestamp(Long timestamp) { this.timestamp = timestamp; }

    public Map<String, Object> getMetrics() { return metrics; }
    public void setMetrics(Map<String, Object> metrics) { this.metrics = metrics; }

    @Override
    public String toString() {
        return "TelemetryPayload{agent_id='" + agent_id + "', timestamp=" + timestamp
                + ", metrics=" + metrics + "}";
    }
}
