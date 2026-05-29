# ── Cloudflare ────────────────────────────────────────────────────────────────
variable "cloudflare_api_token" {
  description = "Token de API de Cloudflare con permisos para Tunnel, DNS y Workers"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "ID de tu cuenta de Cloudflare"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "ID de la zona (dominio) en Cloudflare"
  type        = string
}

variable "domain_name" {
  description = "Dominio base del proyecto (ej. webhardmon.com)"
  type        = string
}

variable "cloud_run_backend_url" {
  description = "Hostname de la instancia Cloud Run (Web Host) para el Worker de URL rewrite"
  type        = string
}

# ── Proxmox ───────────────────────────────────────────────────────────────────
variable "proxmox_api_url" {
  description = "URL de la API de Proxmox (ej. https://10.10.1.10:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Token ID de Proxmox: usuario@realm!nombre-token"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Secreto del token de Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Nombre del nodo Proxmox destino"
  type        = string
}

# ── LXC ───────────────────────────────────────────────────────────────────────
variable "lxc_ostemplate" {
  description = "Plantilla OS del LXC (debe existir en el nodo)"
  type        = string
}

variable "lxc_password" {
  description = "Contraseña root del contenedor"
  type        = string
  sensitive   = true
}

variable "lxc_storage" {
  description = "Almacenamiento donde se crea el disco del LXC"
  type        = string
  default     = "local-lvm"
}

variable "lxc_disk_size" {
  description = "Tamaño del disco raíz"
  type        = string
  default     = "15G"
}

variable "lxc_cores" {
  description = "Núcleos de CPU"
  type        = number
  default     = 2
}

variable "lxc_memory" {
  description = "Memoria RAM en MB"
  type        = number
  default     = 1024
}

# ── Red ───────────────────────────────────────────────────────────────────────
variable "lxc_bridge" {
  description = "Bridge de red del host Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "lxc_ip" {
  description = "IP estática del LXC Colector (sin máscara)"
  type        = string
  default     = "10.10.1.51"
}

variable "lxc_gateway" {
  description = "Puerta de enlace del LXC"
  type        = string
  default     = "10.10.1.1"
}

# ── SSH ───────────────────────────────────────────────────────────────────────
variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Ruta a la clave privada SSH"
  type        = string
}

variable "lxc_nameserver" {
  description = "Servidores DNS del LXC (separados por espacio)"
  type        = string
  default     = "8.8.8.8 8.8.4.4"
}

# ── Servicios internos ────────────────────────────────────────────────────────
variable "docker_registry_ip" {
  description = "IP del Docker Registry privado"
  type        = string
  default     = "10.10.1.50"
}

variable "kafka_ip" {
  description = "IP del broker Kafka"
  type        = string
  default     = "10.10.1.52"
}
