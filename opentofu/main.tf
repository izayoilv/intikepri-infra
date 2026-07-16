terraform {
  required_version = ">=1.12.4"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.22.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.10.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "vault" {
  address         = var.openbao_addr
  token           = var.openbao_token
  skip_tls_verify = true
}
