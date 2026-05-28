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
# LXC: Apache Kafka en modo KRaft (10.10.1.52)
#
# Kafka 3.9 con KRaft — sin Zookeeper.
# Un único broker para el entorno de desarrollo/staging.
# Topic: raw-telemetry (particiones=3, replication-factor=1)
# ══════════════════════════════════════════════════════════════════════════
resource "proxmox_lxc" "kafka" {
  target_node  = var.proxmox_node
  hostname     = "webhardmon-kafka"
  ostemplate   = var.lxc_ostemplate
  password     = var.lxc_password
  unprivileged = true
  onboot       = true
  start        = true
  nameserver   = "172.17.18.2 8.8.8.8"

  ssh_public_keys = file(var.ssh_public_key_path)

  # Docker necesita nesting para funcionar dentro de LXC no-privilegiado
  features {
    nesting = true
  }

  rootfs {
    storage = var.lxc_storage
    size    = var.lxc_disk_size
  }

  # IP estática: 10.10.1.52
  network {
    name   = "eth0"
    bridge = var.lxc_bridge
    ip     = "${var.lxc_ip}/24"
    gw     = var.lxc_gateway
  }

  # Kafka requiere más memoria que el Colector
  cores  = var.lxc_cores
  memory = var.lxc_memory
  swap   = 1024

  # ── Conexión SSH ──────────────────────────────────────────────────────
  connection {
    type        = "ssh"
    host        = var.lxc_ip
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  # ── Provisioner: instalar Docker y desplegar Kafka KRaft ──────────────
  provisioner "remote-exec" {
    inline = [
      "echo '=== [1/4] Esperando a que el LXC esté listo ==='",
      "sleep 15",

      # ── 1. Instalar Docker ────────────────────────────────────────────
      "echo '=== [2/4] Instalando Docker ==='",
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

      # ── 2. Crear directorio de persistencia de datos de Kafka ─────────
      "echo '=== [3/4] Preparando almacenamiento de Kafka ==='",
      "mkdir -p /var/lib/kafka/data",

      # ── 3. Arrancar Kafka 3.9 en modo KRaft ───────────────────────────
      # Variables de entorno clave:
      #   KAFKA_NODE_ID=1                       → ID único del broker (KRaft)
      #   KAFKA_PROCESS_ROLES=broker,controller  → Este nodo es broker Y controller
      #   KAFKA_CONTROLLER_QUORUM_VOTERS        → Lista de voters del quórum KRaft
      #   KAFKA_LISTENERS                       → Dónde escucha internamente
      #   KAFKA_ADVERTISED_LISTENERS            → Qué dirección anuncian a los clientes
      #   KAFKA_AUTO_CREATE_TOPICS_ENABLE=false → Solo creamos topics explícitamente
      "echo '=== [4/4] Arrancando Kafka 3.9 KRaft ==='",
      "docker run -d --name kafka --restart always \\",
      "  -p 9092:9092 \\",
      "  -v /var/lib/kafka/data:/var/lib/kafka/data \\",
      "  -e KAFKA_NODE_ID=1 \\",
      "  -e KAFKA_PROCESS_ROLES=broker,controller \\",
      "  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \\",
      "  -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092,CONTROLLER://localhost:9093 \\",
      "  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://${var.lxc_ip}:9092 \\",
      "  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT \\",
      "  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \\",
      "  -e KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT \\",
      "  -e KAFKA_LOG_DIRS=/var/lib/kafka/data \\",
      "  -e KAFKA_AUTO_CREATE_TOPICS_ENABLE=false \\",
      "  -e KAFKA_DEFAULT_REPLICATION_FACTOR=1 \\",
      "  -e KAFKA_NUM_PARTITIONS=3 \\",
      "  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \\",
      "  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \\",
      "  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \\",
      "  apache/kafka:3.9.0",

      # ── 4. Esperar y crear el topic raw-telemetry ──────────────────────
      "echo '=== Esperando a que Kafka esté listo (30s) ==='",
      "sleep 30",
      "docker exec kafka /opt/kafka/bin/kafka-topics.sh \\",
      "  --create \\",
      "  --topic raw-telemetry \\",
      "  --partitions 3 \\",
      "  --replication-factor 1 \\",
      "  --bootstrap-server localhost:9092",

      # Verificar
      "echo '=== Topics disponibles en Kafka ==='",
      "docker exec kafka /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092",

      "echo '=== Kafka desplegado correctamente ==='"
    ]
  }
}
