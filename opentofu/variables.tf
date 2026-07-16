variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS and Tunnel permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for intikepri.com"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "openbao_addr" {
  description = "OpenBao server address"
  type        = string
  default     = "http://intikepri-openbao.intikepri-openbao.svc:8200"
}

variable "openbao_token" {
  description = "OpenBao root token"
  type        = string
  sensitive   = true
}
