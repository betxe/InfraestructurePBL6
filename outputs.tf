# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────
output "tunnel_id" {
  description = "ID del túnel Cloudflare creado"
  value       = cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.id
}

output "collector_endpoint" {
  description = "URL pública para enviar telemetría (agentes)"
  value       = "https://collector.${var.domain_name}"
}

output "web_frontend_endpoint" {
  description = "URL pública de acceso para usuarios"
  value       = "https://web.${var.domain_name}"
}

# ── Colector LXC ──────────────────────────────────────────────────────────────
output "colector_ip" {
  description = "IP interna del LXC Colector"
  value       = var.lxc_ip
}

output "colector_endpoint_internal" {
  description = "Endpoint interno del Colector"
  value       = "http://${var.lxc_ip}:8080"
}

output "colector_health_url" {
  description = "URL de health check del Colector (Spring Actuator)"
  value       = "http://${var.lxc_ip}:8080/actuator/health"
}
