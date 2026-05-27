# ── Outputs: información del LXC creado ──

output "lxc_ip" {
  description = "IP del contenedor LXC (usar esta IP en el inventory.ini de Ansible)"
  value       = var.lxc_ip
}

output "lxc_hostname" {
  description = "Hostname del contenedor LXC"
  value       = proxmox_lxc.docker_registry.hostname
}
