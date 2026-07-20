# Operations

## OpenBao

### Unseal After Node Reboot

OpenBao reseals on node restart. Unseal with 3 of 5 keys:

```bash
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator unseal <key1>
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator unseal <key2>
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator unseal <key3>
```

### Verify Health

```bash
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao status
```

### Seal

```bash
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- bao operator seal
```

## Managing Sensitive Data

Sensitive data should be stored in OpenBao, not in the bootstrap Secret.

### Adding a new secret

```bash
# 1. Write to OpenBao
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/myapp/mysecret key=value

# 2. Create an ExternalSecret to sync it to a Kubernetes Secret
# (see clusters/default/platform/eso-resources/ for examples)

# 3. Reference the Kubernetes Secret in the Terraform CRD's varsFrom
```

### Webhook tokens for image automation

The `intikepri-static-webhook` ExternalSecret syncs the webhook token from `kv/intikepri-static/webhook-token` in intikepri-openbao. This token is used by both the Forgejo and Docker Hub webhook Receivers in kudofools-infra.

To set it up:

```bash
# 1. Generate a random token
WEBHOOK_TOKEN=$(openssl rand -base64 32)

# 2. Write to intikepri-openbao
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-static/webhook-token token=$WEBHOOK_TOKEN

# 3. Get the Receiver webhook paths
GIT_PATH=$(kubectl get receiver -n flux-system intikepri-static-git -o jsonpath='{.status.webhookPath}')
IMAGE_PATH=$(kubectl get receiver -n flux-system intikepri-static-image -o jsonpath='{.status.webhookPath}')

echo "Forgejo webhook URL: http://notification-controller.flux-system.svc.cluster.local:80$GIT_PATH"
echo "Docker Hub webhook URL: http://notification-controller.flux-system.svc.cluster.local:80$IMAGE_PATH"
```

### Forgejo webhook configuration

In the intikepri-static repo on Forgejo, go to **Settings → Webhooks → Add Webhook** and select **Forgejo** as the type:

| Field | Value |
|---|---|
| Target URL | `http://notification-controller.flux-system.svc.cluster.local:80<git-webhook-path>` |
| HTTP Method | POST |
| POST Content Type | `application/json` |
| Secret | the token from `kv/intikepri-static/webhook-token` |
| Trigger On | Push Events |
| Branch filter | `main` |
| Authorization header | leave empty |

Flux validates the webhook via `X-Hub-Signature` HMAC using the shared secret, not the Authorization header.

### Docker Hub webhook configuration

In the `izayoilv/intikepri-static` repo on Docker Hub, go to **Webhooks** tab:

| Field | Value |
|---|---|
| **Name** | `Flux Image Automation` |
| **URL** | `http://notification-controller.flux-system.svc.cluster.local:80<image-webhook-path>` |

No secret, no content type, no event selection. Docker Hub sends a POST to that URL on every image push. The token is embedded in the webhook path itself (Flux generates a unique path from Receiver name + namespace + token), so no separate secret field is needed.

To get the webhook paths:

```bash
# Forgejo webhook
kubectl get receiver -n flux-system intikepri-static-git -o jsonpath='{.status.webhookPath}'
# → /hook/abc123...  (full URL: http://notification-controller.flux-system.svc.cluster.local:80/hook/abc123...)

# Docker Hub webhook
kubectl get receiver -n flux-system intikepri-static-image -o jsonpath='{.status.webhookPath}'
# → /hook/def456...  (full URL: http://notification-controller.flux-system.svc.cluster.local:80/hook/def456...)
```

### Bootstrap secrets

The `intikepri-opentofu-secrets` Secret in `flux-system` contains bootstrap credentials (`cloudflare_api_token`, `openbao_token`, `cloudflare_zone_id`, `cloudflare_account_id`). These are the keys to the kingdom and must be provided manually — they can't come from OpenBao since OpenTofu configures OpenBao itself. Keep them secure and rotate periodically.

## Cloudflare Tunnel

The tunnel credentials and config are managed by OpenTofu (created as a Kubernetes Secret and ConfigMap in `kube-system`). If the tunnel is recreated, both are updated automatically by the next OpenTofu reconciliation. Force reconcile if needed:

```bash
kubectl annotate terraform -n flux-system intikepri-opentofu reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
```

## Updating OpenTofu Configs

1. Edit files in `opentofu/`
2. Push to main branch
3. tofu-controller auto-detects changes and applies

To force immediate reconciliation instead of waiting for the interval:

```bash
# Force tofu-controller to reconcile
kubectl annotate terraform -n flux-system intikepri-opentofu reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux

# Force ExternalSecret to reconcile
kubectl annotate externalsecret -n <namespace> <name> reconcile.external-secrets.io/force="true" --field-manager=flux
```

## Drift Recovery

If tofu-controller reports drift:

```bash
kubectl get terraform -n flux-system intikepri-opentofu -o yaml
kubectl describe terraform -n flux-system intikepri-opentofu
```
