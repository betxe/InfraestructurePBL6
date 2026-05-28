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
  description = "Plantilla OS del LXC"
  type        = string
}

variable "lxc_password" {
  description = "Contraseña root del contenedor"
  type        = string
  sensitive   = true
}

variable "lxc_storage" {
  description = "Almacenamiento donde se crea el disco"
  type        = string
  default     = "local-lvm"
}

variable "lxc_disk_size" {
  description = "Tamaño del disco raíz (Kafka necesita espacio para logs)"
  type        = string
  default     = "30G"
}

variable "lxc_cores" {
  description = "Núcleos de CPU"
  type        = number
  default     = 2
}

variable "lxc_memory" {
  description = "Memoria RAM en MB (Kafka necesita mínimo 2GB)"
  type        = number
  default     = 2048
}

# ── Red ───────────────────────────────────────────────────────────────────
variable "lxc_bridge" {
  description = "Bridge de red del host Proxmox"
  type        = string
  default     = "vmbr0"
}

variable "lxc_ip" {
  description = "IP estática del LXC Kafka (sin máscara)"
  type        = string
  default     = "10.10.1.52"
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
