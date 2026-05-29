terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# ==========================================
# PILAR 1: CLOUDFLARE TUNNEL (COLECTOR)
# ==========================================

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "colector_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "webhardmon-colector-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "colector_tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.id

  config {
    ingress_rule {
      hostname = "collector.${var.domain_name}"
      service  = "http://localhost:8080"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "collector_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "collector"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# ==========================================
# PILAR 2: CLOUDFLARE WORKERS (CLOUD RUN)
# ==========================================

resource "cloudflare_workers_script" "url_rewrite_worker" {
  account_id = var.cloudflare_account_id
  name       = "webhardmon-url-rewriter"
  content    = <<EOT
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  url.hostname = "${var.cloud_run_backend_url}"
  const modifiedRequest = new Request(url, {
    method: request.method,
    headers: request.headers,
    body: request.body,
    redirect: request.redirect
  })
  return fetch(modifiedRequest)
}
EOT
}

resource "cloudflare_workers_route" "worker_route" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "web.${var.domain_name}/*"
  script_name = cloudflare_workers_script.url_rewrite_worker.name
}

resource "cloudflare_record" "web_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "web"
  content = "100::"
  type    = "AAAA"
  proxied = true
}

# ==========================================
# PILAR 3: LXC COLECTOR (Proxmox)
# ==========================================

resource "proxmox_lxc" "colector" {
  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared_config.colector_tunnel_config,
    cloudflare_record.collector_dns,
  ]

  target_node  = var.proxmox_node
  hostname     = "webhardmon-colector"
  ostemplate   = var.lxc_ostemplate
  password     = var.lxc_password
  unprivileged = true
  onboot       = true
  start        = true
  nameserver   = var.lxc_nameserver

  ssh_public_keys = file(var.ssh_public_key_path)

  features {
    nesting = true
  }

  rootfs {
    storage = var.lxc_storage
    size    = var.lxc_disk_size
  }

  network {
    name   = "eth0"
    bridge = var.lxc_bridge
    ip     = "${var.lxc_ip}/24"
    gw     = var.lxc_gateway
  }

  cores  = var.lxc_cores
  memory = var.lxc_memory
  swap   = 512
}

# Espera a que el LXC complete su boot inicial antes de conectar por SSH.
# Proxmox reinicia servicios (incluido sshd) durante la inicialización del
# contenedor desde template, lo que causa que las conexiones SSH inmediatas
# se corten sin código de salida.
resource "time_sleep" "wait_for_colector_boot" {
  depends_on      = [proxmox_lxc.colector]
  create_duration = "60s"
}

resource "null_resource" "provision_colector" {
  depends_on = [time_sleep.wait_for_colector_boot]

  triggers = {
    lxc_id = proxmox_lxc.colector.id
  }

  connection {
    type        = "ssh"
    host        = var.lxc_ip
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  # Bloque 1: Docker + Colector — output visible (sin valores sensibles)
  provisioner "remote-exec" {
    inline = [
      # ── 1. Instalar Docker Engine ────────────────────────────────────────
      "echo '=== [1/4] Instalando Docker ==='",
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get update -qq",
      "apt-get install -y -qq ca-certificates curl gnupg",
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc",
      "chmod a+r /etc/apt/keyrings/docker.asc",
      ". /etc/os-release && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable\" > /etc/apt/sources.list.d/docker.list",
      "apt-get update -qq",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "systemctl enable docker",
      "systemctl start docker",

      # ── 2. Configurar acceso al Docker Registry privado (HTTP inseguro) ──
      "echo '=== [2/4] Configurando Docker Registry privado ==='",
      "mkdir -p /etc/docker",
      "echo '{\"insecure-registries\": [\"${var.docker_registry_ip}:5000\"]}' > /etc/docker/daemon.json",
      "systemctl restart docker",
      "sleep 5",

      # ── 3. Pull y arranque del Colector ──────────────────────────────────
      "echo '=== [3/4] Descargando imagen del Colector ==='",
      "timeout 120 docker pull ${var.docker_registry_ip}:5000/colector:latest",

      "echo '=== [4/4] Arrancando el Colector ==='",
      "docker run -d --name colector --restart always \\",
      "  -p 8080:8080 \\",
      "  -e KAFKA_BOOTSTRAP_SERVERS=${var.kafka_ip}:9092 \\",
      "  -e KAFKA_TOPIC=raw-telemetry \\",
      "  ${var.docker_registry_ip}:5000/colector:latest",

      "echo '=== Docker y Colector listos ==='",
      "docker ps"
    ]
  }

  # Bloque 2: cloudflared — output suprimido por el token sensible
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list",
      "apt-get update -qq",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cloudflared",
      "cloudflared service install ${cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.tunnel_token} || echo '[WARN] cloudflared service install failed'",
      "sed -i 's/tunnel run/tunnel run --protocol http2/g' /etc/systemd/system/cloudflared.service || true",
      "systemctl daemon-reload || true",
      "systemctl enable cloudflared || true",
      "systemctl start cloudflared || echo '[WARN] cloudflared no pudo arrancar'",
      "systemctl is-active cloudflared && echo '[OK] cloudflared activo' || echo '[WARN] cloudflared inactivo'"
    ]
  }
}
