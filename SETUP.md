# Setup

## Prerequisites

- k3s cluster with Traefik installed
- Flux bootstrapped via [kudofools-infra](https://forgejo.kudofools.dev/izayoilv/kudofools-infra)
- Cloudflare account with intikepri.com zone
- `bao` CLI installed locally

## Initial Setup

### 1. Create Bootstrap Secret for tofu-controller

The OpenTofu configs need Cloudflare and OpenBao credentials. Create this Secret before tofu-controller applies:

```bash
kubectl create secret generic -n flux-system intikepri-opentofu-secrets \
  --from-literal=cloudflare_api_token='<token>' \
  --from-literal=openbao_token=$ROOT_TOKEN \
  --from-literal=cloudflare_zone_id='<zone-id>' \
  --from-literal=cloudflare_account_id='<account-id>'
```

These are bootstrap secrets — they can't come from OpenBao since OpenTofu is configuring OpenBao itself.

### 2. Init and Unseal OpenBao

```bash
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator init -format=json > ~/.intikepri-bao-keys.json

kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator unseal $(jq -r '.unseal_keys_hex[0]' ~/.intikepri-bao-keys.json)
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator unseal $(jq -r '.unseal_keys_hex[1]' ~/.intikepri-bao-keys.json)
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator unseal $(jq -r '.unseal_keys_hex[2]' ~/.intikepri-bao-keys.json)

ROOT_TOKEN=$(jq -r '.root_token' ~/.intikepri-bao-keys.json)
```

### 3. Verify tofu-controller Applied OpenTofu Config

The tofu-controller should auto-apply `opentofu/` configs (KV mount, policies, Kubernetes auth role).

```bash
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao secrets list
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao policy list
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao read auth/kubernetes/config
```

### 4. Verify DNS Records

The OpenTofu config also creates Cloudflare DNS records and the tunnel credentials Secret. Check the Terraform status:

```bash
kubectl describe terraform -n flux-system intikepri-opentofu
```

If the apply succeeded, the cloudflared pod should start automatically once the credentials Secret and ConfigMap are created by OpenTofu.

### 5. Configure Web UI user

OpenTofu enables userpass auth and creates a ui-admin policy. Create your admin user with a generated password:

```bash
ROOT_TOKEN=$(jq -r '.root_token' ~/.intikepri-bao-keys.json)

UI_PASS=$(openssl rand -base64 32)
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao write auth/userpass/users/admin \
  password=$UI_PASS token_policies=ui-admin

echo "Web UI password: $UI_PASS"
```

Log in at https://openbao.intikepri.com/ui/ with the password above. The username is `admin`.

You can create additional users the same way, optionally with more restrictive policies.
