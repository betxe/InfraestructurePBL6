terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

# ── Provider: conexión a la API de Proxmox ──
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# ── Recurso: Contenedor LXC para Docker Registry ──
resource "proxmox_lxc" "docker_registry" {
  target_node  = var.proxmox_node
  hostname     = var.lxc_hostname
  ostemplate   = var.lxc_ostemplate
  password     = var.lxc_password
  unprivileged = true
  onboot       = true
  start        = true
  nameserver   = "172.17.18.2 8.8.8.8"

  # Clave SSH para acceso sin contraseña (necesario para Ansible)
  ssh_public_keys = file(var.ssh_public_key_path)

  # Features necesarias para ejecutar Docker dentro del LXC
  features {
    nesting = true
    # keyctl  = true
  }

  # Disco raíz
  rootfs {
    storage = var.lxc_storage
    size    = var.lxc_disk_size
  }

  # Red con IP estática (imprescindible para Ansible)
  network {
    name   = "eth0"
    bridge = var.lxc_bridge
    ip     = "${var.lxc_ip}/24"
    gw     = var.lxc_gateway
  }

  # Recursos
  cores  = var.lxc_cores
  memory = var.lxc_memory
  swap   = 512

  # ── Conexión SSH para los provisioners ──
  connection {
    type        = "ssh"
    host        = var.lxc_ip
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  # ── Esperar a que el LXC arranque y SSH esté disponible ──
  provisioner "remote-exec" {
    inline = [
      "echo 'Esperando a que el sistema esté listo...'",
      "sleep 15",

      # 1. Instalar dependencias (wget viene en la plantilla base, curl no)
      "apt-get update",
      "apt-get install -y ca-certificates curl gnupg",

      # 2. Añadir repositorio oficial de Docker
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc",
      "chmod a+r /etc/apt/keyrings/docker.asc",
      ". /etc/os-release && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable\" > /etc/apt/sources.list.d/docker.list",

      # 3. Instalar Docker Engine
      "apt-get update",
      "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",

      # 4. Habilitar y arrancar Docker
      "systemctl enable docker",
      "systemctl start docker",

      # 5. Crear directorio de persistencia y levantar Docker Registry
      "mkdir -p /var/lib/registry",
      "docker run -d --name registry --restart always -p 5000:5000 -v /var/lib/registry:/var/lib/registry registry:2",

      # 6. Verificar
      "echo '=== Docker Registry desplegado correctamente ==='",
      "docker ps"
    ]
  }
}