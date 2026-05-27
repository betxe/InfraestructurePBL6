# ╔══════════════════════════════════════════╗
# ║       Conexión a la API de Proxmox       ║
# ╚══════════════════════════════════════════╝

variable "proxmox_api_url" {
  description = "URL de la API de Proxmox (ej: https://192.168.1.100:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Token ID en formato usuario@realm!nombre-token"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Token Secret (UUID)"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Nombre del nodo Proxmox donde crear el LXC"
  type        = string
  default     = "pve"
}

# ╔══════════════════════════════════════════╗
# ║        Configuración del LXC             ║
# ╚══════════════════════════════════════════╝

variable "lxc_hostname" {
  description = "Hostname del contenedor LXC"
  type        = string
  default     = "docker-registry"
}

variable "lxc_ostemplate" {
  description = "Ruta de la plantilla LXC en Proxmox (ej: local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)"
  type        = string
}

variable "lxc_password" {
  description = "Contraseña del usuario root del LXC"
  type        = string
  sensitive   = true
}

variable "lxc_storage" {
  description = "Storage de Proxmox para el disco raíz del LXC"
  type        = string
  default     = "local-lvm"
}

variable "lxc_disk_size" {
  description = "Tamaño del disco raíz del LXC"
  type        = string
  default     = "20G"
}

variable "lxc_cores" {
  description = "Número de cores asignados al LXC"
  type        = number
  default     = 2
}

variable "lxc_memory" {
  description = "Memoria RAM en MB asignada al LXC"
  type        = number
  default     = 2048
}

# ╔══════════════════════════════════════════╗
# ║              Red del LXC                 ║
# ╚══════════════════════════════════════════╝

variable "lxc_bridge" {
  description = "Bridge de red de Proxmox (normalmente vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "lxc_ip" {
  description = "IP estática del LXC (sin máscara, ej: 192.168.1.50)"
  type        = string
}

variable "lxc_gateway" {
  description = "Gateway de la red del LXC"
  type        = string
}

# ╔══════════════════════════════════════════╗
# ║                  SSH                     ║
# ╚══════════════════════════════════════════╝

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH para inyectar en el LXC"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Ruta a la clave privada SSH (usada por el provisioner para conectarse al LXC)"
  type        = string
  default     = "~/.ssh/id_rsa"
}