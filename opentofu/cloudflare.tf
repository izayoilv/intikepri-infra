resource "random_id" "tunnel_secret" {
  byte_length  = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "intikepri" {
  account_id    = var.cloudflare_account_id
  name          = "intikepri-tunnel"
  tunnel_secret = random_id.tunnel_secret.b64_std
}

locals {
  credentials_json = jsonencode({
    AccountTag   = var.cloudflare_account_id
    TunnelID     = cloudflare_zero_trust_tunnel_cloudflared.intikepri.id
    TunnelSecret = random_id.tunnel_secret.b64_std
    TunnelName   = "intikepri-tunnel"
  })

  config_yaml = <<-EOF
    tunnel: ${cloudflare_zero_trust_tunnel_cloudflared.intikepri.id}
    credentials-file: /etc/cloudflared/credentials.json
    transport-loglevel: warn
    ingress:
      - service: http://traefik.kube-system.svc.cluster.local:80
  EOF
}

resource "kubernetes_secret_v1" "cloudflared_credentials" {
  metadata {
    name      = "intikepri-cloudflared-credentials"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"       = "intikepri-cloudflared"
      "app.kubernetes.io/part-of"    = "intikepri"
      "app.kubernetes.io/managed-by" = "flux"
    }
  }
  type = "Opaque"
  data = {
    "credentials.json" = local.credentials_json
  }
}

resource "kubernetes_config_map_v1" "cloudflared_config" {
  metadata {
    name      = "intikepri-cloudflared-config"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"       = "intikepri-cloudflared"
      "app.kubernetes.io/part-of"    = "intikepri"
      "app.kubernetes.io/managed-by" = "flux"
    }
  }
  data = {
    "config.yaml" = local.config_yaml
  }
}

resource "cloudflare_dns_record" "intikepri_com_apex" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.intikepri.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "intikepri_com_www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.intikepri.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "openbao_intikepri_com" {
  zone_id = var.cloudflare_zone_id
  name    = "openbao"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.intikepri.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "api_intikepri_com" {
  zone_id = var.cloudflare_zone_id
  name    = "api"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.intikepri.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "admin_intikepri_com" {
  zone_id = var.cloudflare_zone_id
  name    = "admin"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.intikepri.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_ruleset" "www_redirect" {
  zone_id     = var.cloudflare_zone_id
  name        = "redirect-www-to-apex"
  description = "Permanent redirect www.intikepri.com to intikepri.com"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [{
    description = "Redirect www to apex"
    expression  = "(http.host eq \"www.intikepri.com\")"
    action      = "redirect"
    enabled     = true
    action_parameters = {
      from_value = {
        status_code = 301
        preserve_query_string = true
        target_url = {
          expression = "concat(\"https://intikepri.com\", http.request.uri.path)"
        }
      }
    }
  }]
}
