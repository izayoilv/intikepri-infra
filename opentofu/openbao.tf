resource "vault_auth_backend" "kubernetes" {
  type     = "kubernetes"
  path     = "kubernetes"
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

resource "vault_policy" "intikepri_static" {
  name     = "intikepri-static"
  policy   = <<EOT
path "kv/data/intikepri-static/*" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "eso" {
  backend                        = vault_kubernetes_auth_backend_config.kubernetes.backend
  role_name                      = "eso"
  bound_service_account_names    = ["external-secrets"]
  bound_service_account_namespaces = ["flux-system"]
  token_policies                 = [vault_policy.intikepri_static.name]
  token_ttl                      = 3600
}

resource "vault_auth_backend" "userpass" {
  type     = "userpass"
  path     = "userpass"
}

resource "vault_policy" "ui_admin" {
  name     = "ui-admin"
  policy   = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}
