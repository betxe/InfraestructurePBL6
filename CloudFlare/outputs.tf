output "tunnel_id" {
  description = "ID único del túnel creado"
  value       = cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.id
}

output "tunnel_token" {
  description = "TOKEN SECRETO. Utilízalo en tu servidor local para arrancar el demonio cloudflared"
  value       = cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.tunnel_token
  sensitive   = true
}

output "collector_endpoint" {
  description = "URL pública donde los agentes deben enviar la telemetría"
  value       = "https://collector.${var.domain_name}"
}

output "web_frontend_endpoint" {
  description = "URL pública de acceso para los usuarios (gestor del URL Rewrite)"
  value       = "https://web.${var.domain_name}"
}