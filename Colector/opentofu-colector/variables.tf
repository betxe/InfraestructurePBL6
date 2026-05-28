# ── Proxmox ──────────────────────────────────────────────────────────────
variable "proxmox_api_url" {
  description = "URL de la API de Proxmox"
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

# ── LXC ──────────────────────────────────────────────────────────────────
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

# ── Red ───────────────────────────────────────────────────────────────────
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
  description = "Puerta de enlace"
  type        = string
  default     = "10.10.1.1"
}

# ── SSH ───────────────────────────────────────────────────────────────────
variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Ruta a la clave privada SSH"
  type        = string
}

# ── Servicios internos ────────────────────────────────────────────────────
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

variable "cloudflare_tunnel_token" {
  description = "Token del Cloudflare Tunnel generado por OpenTofu (output tunnel_token del módulo CloudFlare)"
  type        = string
  sensitive   = true
}
