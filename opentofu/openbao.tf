resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc"
}

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv-v2"
  description = "KV v2 secrets engine for intikepri"
}

resource "vault_mount" "transit" {
  path        = "transit"
  type        = "transit"
  description = "Transit secrets engine for JWT signing and verification"
}

resource "vault_transit_secret_backend_key" "intikepri_cms_jwt" {
  backend = vault_mount.transit.path
  name    = "intikepri-cms-jwt"
  type    = "ed25519"
}

resource "vault_policy" "intikepri_static" {
  name   = "intikepri-static"
  policy = <<EOT
path "kv/data/intikepri-static/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "intikepri_cms" {
  name   = "intikepri-cms"
  policy = <<EOT
path "kv/data/intikepri-cms/*" {
  capabilities = ["read"]
}

path "transit/keys/intikepri-cms-jwt" {
  capabilities = ["read"]
}

path "transit/sign/intikepri-cms-jwt" {
  capabilities = ["update"]
}

path "transit/verify/intikepri-cms-jwt" {
  capabilities = ["update"]
}
EOT
}

resource "vault_policy" "intikepri_infra" {
  name   = "intikepri-infra"
  policy = <<EOT
path "kv/data/intikepri-infra/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "eso" {
  backend                          = vault_kubernetes_auth_backend_config.kubernetes.backend
  role_name                        = "eso"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["flux-system"]
  token_policies                   = [vault_policy.intikepri_static.name, vault_policy.intikepri_cms.name, vault_policy.intikepri_infra.name]
  token_ttl                        = 3600
}

resource "vault_kubernetes_auth_backend_role" "intikepri_cms" {
  backend                          = vault_kubernetes_auth_backend_config.kubernetes.backend
  role_name                        = "intikepri-cms"
  bound_service_account_names      = ["intikepri-cms"]
  bound_service_account_namespaces = ["intikepri-cms"]
  token_policies                   = [vault_policy.intikepri_cms.name]
  token_ttl                        = 3600
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}

resource "vault_policy" "ui_admin" {
  name   = "ui-admin"
  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}
