terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

# ── Provider: conexión a la API de Proxmox ──────────────────────────────
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# ══════════════════════════════════════════════════════════════════════════
# LXC: Colector WebHardMon (10.10.1.51)
#
# Este contenedor aloja:
#   1. Docker Engine
#   2. La imagen del Colector (pull desde el Docker Registry privado 10.10.1.50:5000)
#   3. El daemon cloudflared (Cloudflare Tunnel) que enruta el tráfico externo al Colector
# ══════════════════════════════════════════════════════════════════════════
resource "proxmox_lxc" "colector" {
  target_node  = var.proxmox_node
  hostname     = "webhardmon-colector"
  ostemplate   = var.lxc_ostemplate
  password     = var.lxc_password
  unprivileged = true
  onboot       = true
  start        = true
  nameserver   = "172.17.18.2 8.8.8.8"

  # Clave SSH para acceso sin contraseña (necesario para los provisioners)
  ssh_public_keys = file(var.ssh_public_key_path)

  # Docker necesita nesting para funcionar dentro de LXC no-privilegiado
  features {
    nesting = true
  }

  # Disco raíz
  rootfs {
    storage = var.lxc_storage
    size    = var.lxc_disk_size
  }

  # IP estática: 10.10.1.51
  network {
    name   = "eth0"
    bridge = var.lxc_bridge
    ip     = "${var.lxc_ip}/24"
    gw     = var.lxc_gateway
  }

  cores  = var.lxc_cores
  memory = var.lxc_memory
  swap   = 512

  # ── Conexión SSH para los provisioners ──────────────────────────────────
  connection {
    type        = "ssh"
    host        = var.lxc_ip
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  # ── Provisioner: instalar Docker, levantar Colector y cloudflared ───────
  provisioner "remote-exec" {
    inline = [
      "echo '=== [1/5] Esperando a que el LXC esté listo ==='",
      "sleep 15",

      # ── 1. Instalar Docker Engine ──────────────────────────────────────
      "echo '=== [2/5] Instalando Docker ==='",
      "apt-get update -qq",
      "apt-get install -y -qq ca-certificates curl gnupg",
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc",
      "chmod a+r /etc/apt/keyrings/docker.asc",
      ". /etc/os-release && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable\" > /etc/apt/sources.list.d/docker.list",
      "apt-get update -qq",
      "apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "systemctl enable docker",
      "systemctl start docker",

      # ── 2. Configurar acceso al Docker Registry privado (HTTP inseguro) ─
      # El registry en 10.10.1.50:5000 no tiene TLS, necesitamos allowlist
      "echo '=== [3/5] Configurando acceso al Docker Registry privado ==='",
      "mkdir -p /etc/docker",
      "echo '{\"insecure-registries\": [\"${var.docker_registry_ip}:5000\"]}' > /etc/docker/daemon.json",
      "systemctl restart docker",
      "sleep 5",

      # ── 3. Pull de la imagen del Colector ──────────────────────────────
      "echo '=== [4/5] Descargando imagen del Colector desde el Registry ==='",
      "docker pull ${var.docker_registry_ip}:5000/colector:latest",

      # ── 4. Arrancar el Colector ─────────────────────────────────────────
      "echo '=== [5/5] Arrancando el Colector ==='",
      "docker run -d --name colector --restart always \\",
      "  -p 8080:8080 \\",
      "  -e KAFKA_BOOTSTRAP_SERVERS=${var.kafka_ip}:9092 \\",
      "  -e KAFKA_TOPIC=raw-telemetry \\",
      "  ${var.docker_registry_ip}:5000/colector:latest",

      # ── 5. Instalar cloudflared (Tunnel daemon) ─────────────────────────
      # NOTA: cloudflared requiere puerto 7844 saliente (TCP+UDP).
      # Si la red lo bloquea, los comandos de 'systemctl start' fallarán.
      # Usamos '|| true' para que el provisioner no se rompa por este motivo.
      # El Colector seguirá funcionando internamente en :8080.
      "echo '=== Instalando cloudflared ==='",
      "curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list",
      "apt-get update -qq",
      "apt-get install -y -qq cloudflared",
      "cloudflared service install ${var.cloudflare_tunnel_token} || echo '[WARN] cloudflared service install failed'",
      "echo '=== Parcheando servicio cloudflared para usar HTTP/2 en puerto 443 ==='",
      "sed -i 's/tunnel run/tunnel run --protocol http2/g' /etc/systemd/system/cloudflared.service || echo '[WARN] No se pudo parchear el archivo de servicio de cloudflared'",
      "systemctl daemon-reload || true",
      "systemctl enable cloudflared || true",
      # Se intenta levantar usando el puerto 443 TCP (HTTPS estándar) que suele estar abierto
      "systemctl start cloudflared || echo '[WARN] cloudflared no pudo arrancar'",

      "echo '=== Colector desplegado correctamente ==='",
      "docker ps",
      "systemctl is-active cloudflared && echo '[OK] cloudflared activo' || echo '[WARN] cloudflared inactivo - tunnel externo no disponible'"
    ]
  }
}
