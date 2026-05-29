variable "cloudflare_api_token" {
  description = "Token de API de Cloudflare con permisos para Zone, DNS y Workers"
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
  description = "El dominio base del proyecto (ej. webhardmon.com)"
  type        = string
}

variable "cloud_run_backend_url" {
  description = "La URL interna o directa de la primera instancia de GCP Cloud Run (Web Host)"
  type        = string
}