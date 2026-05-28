output "colector_ip" {
  description = "IP estática del LXC Colector"
  value       = var.lxc_ip
}

output "colector_endpoint_internal" {
  description = "Endpoint interno del Colector (accesible desde la red Proxmox)"
  value       = "http://${var.lxc_ip}:8080"
}

output "colector_health_url" {
  description = "URL de health check del Colector (Spring Actuator)"
  value       = "http://${var.lxc_ip}:8080/actuator/health"
}
