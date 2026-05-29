# 1. Configuración del Proveedor de Cloudflare
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# 2. Generación automática de un secreto seguro para el túnel
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# ==========================================
# PILAR 1: CLOUDFLARE TUNNEL (COLECTOR)
# ==========================================

# Crear el túnel lógico en Cloudflare
resource "cloudflare_zero_trust_tunnel_cloudflared" "colector_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "webhardmon-colector-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

# Configurar las reglas de enrutamiento interno del túnel
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "colector_tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.colector_tunnel.id

  config {
    # REGLA 1: Todo el tráfico de este subdominio va al puerto local del Colector
    ingress_rule {
      hostname = "collector.${var.domain_name}"
      service  = "http://localhost:8080"
    }

    # REGLA 2: Catch-all obligatorio (Cloudflare requiere una regla por defecto)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Crear el registro DNS tipo CNAME apuntando al túnel
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

# Desplegar el script del Worker para reescritura de URL / Proxying
resource "cloudflare_workers_script" "url_rewrite_worker" {
  account_id = var.cloudflare_account_id
  name       = "webhardmon-url-rewriter"
  content    = <<EOT
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  
  // Modificamos el hostname para que apunte secretamente a Cloud Run
  // Manteniendo el path original y los query params (?empresa_id=1)
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

# Vincular el Worker a una ruta DNS específica (ej: web.webhardmon.com/*)
resource "cloudflare_workers_route" "worker_route" {
  zone_id     = var.cloudflare_zone_id
  pattern     = "web.${var.domain_name}/*"
  script_name = cloudflare_workers_script.url_rewrite_worker.name
}

# Crear el registro DNS para el Worker (Debe existir para que la ruta funcione)
resource "cloudflare_record" "web_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "web"
  content = "100::" # IP Placeholder (AAAA dummy) requerida para activar Workers en un subdominio proxyed
  type    = "AAAA"
  proxied = true
}