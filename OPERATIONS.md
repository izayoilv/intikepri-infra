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

Two separate ExternalSecrets sync webhook tokens from intikepri-openbao, one per project:

| ExternalSecret | OpenBao path | Used by |
|---|---|---|
| `intikepri-static-webhook` | `kv/intikepri-static/webhook-token` | `intikepri-static` Receivers |
| `intikepri-cms-webhook` | `kv/intikepri-cms/webhook-token` | `intikepri-cms` Receivers |
| `intikepri-infra-webhook` | `kv/intikepri-infra/webhook-token` | `intikepri-infra-webhook` Receiver |
| `intikepri-minio` | `kv/intikepri-cms/minio` | MinIO root credentials (`rootUser`, `rootPassword`) |

To set them up:

```bash
# 1. Generate unique tokens
STATIC_TOKEN=$(openssl rand -base64 32)
CMS_TOKEN=$(openssl rand -base64 32)
INFRA_TOKEN=$(openssl rand -base64 32)
MINIO_USER=minio
MINIO_PASS=$(openssl rand -base64 32)

# 2. Write to intikepri-openbao
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-static/webhook-token token=$STATIC_TOKEN
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-cms/webhook-token token=$CMS_TOKEN
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-infra/webhook-token token=$INFRA_TOKEN
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-cms/minio rootUser=$MINIO_USER rootPassword=$MINIO_PASS

# 3. Get the Receiver webhook paths
# intikepri-static
STATIC_GIT_PATH=$(kubectl get receiver -n flux-system intikepri-static-git -o jsonpath='{.status.webhookPath}')
STATIC_IMAGE_PATH=$(kubectl get receiver -n flux-system intikepri-static-image -o jsonpath='{.status.webhookPath}')

echo "intikepri-static Forgejo webhook URL: https://flux-webhook.kudofools.dev$STATIC_GIT_PATH"
echo "intikepri-static Docker Hub webhook URL: https://flux-webhook.kudofools.dev$STATIC_IMAGE_PATH"

# intikepri-cms
CMS_GIT_PATH=$(kubectl get receiver -n flux-system intikepri-cms-git -o jsonpath='{.status.webhookPath}')
CMS_IMAGE_PATH=$(kubectl get receiver -n flux-system intikepri-cms-image -o jsonpath='{.status.webhookPath}')

echo "intikepri-cms Forgejo webhook URL: https://flux-webhook.kudofools.dev$CMS_GIT_PATH"
echo "intikepri-cms Docker Hub webhook URL: https://flux-webhook.kudofools.dev$CMS_IMAGE_PATH"

# intikepri-infra
INFRA_PATH=$(kubectl get receiver -n flux-system intikepri-infra-webhook -o jsonpath='{.status.webhookPath}')
echo "intikepri-infra Forgejo webhook URL: https://flux-webhook.kudofools.dev$INFRA_PATH"
```

### Forgejo webhook configuration

Flux watches both the `intikepri-static` and `intikepri-cms` repos on Forgejo. For each repo, go to **Settings → Webhooks → Add Webhook** and select **Forgejo** as the type:

| Field | Value |
|---|---|
| Target URL | `https://flux-webhook.kudofools.dev<hook>` (where `hook` is the receiver's webhook path) |
| HTTP Method | POST |
| POST Content Type | `application/json` |
| Secret | the token from the project's OpenBao path (`kv/intikepri-static/webhook-token` or `kv/intikepri-cms/webhook-token`) |
| Trigger On | Push Events |
| Branch filter | `main` |
| Authorization header | leave empty |

Flux validates the webhook via `X-Hub-Signature` HMAC using the shared secret, not the Authorization header.

#### intikepri-static

- Forgejo repo: `izayoilv/intikepri-static`
- Receiver: `intikepri-static-git`
- OpenBao path: `kv/intikepri-static/webhook-token`
- Webhook path: retrieve via `kubectl get receiver -n flux-system intikepri-static-git -o jsonpath='{.status.webhookPath}'`

#### intikepri-cms

- Forgejo repo: `izayoilv/intikepri-cms`
- Receiver: `intikepri-cms-git`
- OpenBao path: `kv/intikepri-cms/webhook-token`
- Webhook path: retrieve via `kubectl get receiver -n flux-system intikepri-cms-git -o jsonpath='{.status.webhookPath}'`

#### intikepri-infra (flux-system)

- Forgejo repo: `izayoilv/intikepri-infra`
- Receiver: `intikepri-infra-webhook`
- OpenBao path: `kv/intikepri-infra/webhook-token`
- Webhook path: retrieve via `kubectl get receiver -n flux-system intikepri-infra-webhook -o jsonpath='{.status.webhookPath}'`

### Docker Hub webhook configuration

In each Docker Hub repo, go to **Webhooks** tab:

| Field | Value |
|---|---|
| **Name** | `Flux Image Automation` |
| **URL** | `https://flux-webhook.kudofools.dev<hook>` (where `hook` is the receiver's webhook path) |

No secret, no content type, no event selection. Docker Hub sends a POST to that URL on every image push. The token is embedded in the webhook path itself (Flux generates a unique path from Receiver name + namespace + token), so no separate secret field is needed.

#### intikepri-static

- Docker Hub repo: `izayoilv/intikepri-static`
- Receiver: `intikepri-static-image`
- Kubernetes secret: `intikepri-static-webhook`
- Webhook path: retrieve via `kubectl get receiver -n flux-system intikepri-static-image -o jsonpath='{.status.webhookPath}'`

#### intikepri-cms

- Docker Hub repo: `izayoilv/intikepri-cms`
- Receiver: `intikepri-cms-image`
- Kubernetes secret: `intikepri-cms-webhook`
- Webhook path: retrieve via `kubectl get receiver -n flux-system intikepri-cms-image -o jsonpath='{.status.webhookPath}'`

### Bootstrap secrets

The `intikepri-opentofu-secrets` Secret in `flux-system` contains bootstrap credentials (`cloudflare_api_token`, `openbao_token`, `cloudflare_zone_id`, `cloudflare_account_id`). These are the keys to the kingdom and must be provided manually — they can't come from OpenBao since OpenTofu configures OpenBao itself. Keep them secure and rotate periodically.

## MinIO Object Storage

MinIO is deployed via HelmRelease in `intikepri-minio` namespace using the community chart with Chainguard's hardened image.

### Services

| Service | Hostname | Port | Purpose |
|---------|----------|------|---------|
| S3 API | `s3.intikepri.com` | 9000 | S3-compatible API for the CMS |
| Console | `minio.intikepri.com` | 9001 | Web UI for managing buckets and access keys |

Internal cluster endpoints:
- `minio.intikepri-minio.svc.cluster.local:9000` — S3 API
- `minio-console.intikepri-minio.svc.cluster.local:9001` — Console

### Seeding root credentials

```bash
MINIO_USER=minio
MINIO_PASS=$(openssl rand -base64 32)
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-cms/minio rootUser=$MINIO_USER rootPassword=$MINIO_PASS
echo "User: $MINIO_USER  Pass: $MINIO_PASS"
```

The ExternalSecret `intikepri-minio` in `flux-system` syncs these credentials to a Secret in `intikepri-minio`.

### Accessing the Console

1. Browse to `https://minio.intikepri.com`
2. Log in with `rootUser`/`rootPassword` from the seeded credentials
3. Navigate the object browser to view/manage the `intikepri-cms` bucket

### Creating an access key for the CMS

From the Console, go to **Access Keys → Create access key**:

| Field | Value |
|-------|-------|
| Access Key | auto-generated (or set manually) |
| Secret Key | auto-generated (save immediately — shown once) |
| Restrict beyond user policy | optional — scope to `intikepri-cms` bucket |

Save the generated key and secret. You'll need to seed them into OpenBao for the CMS:

```bash
kubectl exec -n intikepri-openbao intikepri-openbao-0 -- env BAO_TOKEN=$ROOT_TOKEN bao kv put kv/intikepri-cms/minio-access-key accessKey=<key> secretKey=<secret>
```

Then create an ExternalSecret to sync them into the `intikepri-cms` namespace (see `clusters/default/platform/eso-resources/` for examples).

### Reconciling

```bash
flux reconcile helmrelease -n flux-system minio
```

### Health check

```bash
kubectl get pods -n intikepri-minio
kubectl logs -n intikepri-minio -l app.kubernetes.io/name=intikepri-minio
```

## Cloudflare Tunnel

The tunnel credentials and config are managed by OpenTofu (created as a Kubernetes Secret and ConfigMap in `kube-system`). If the tunnel is recreated, both are updated automatically by the next OpenTofu reconciliation. Force reconcile if needed:

```bash
kubectl annotate terraform -n flux-system intikepri-opentofu reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
```

## Reconciling Image Automation Resources

To force immediate reconciliation of image automation resources instead of waiting for the polling interval:

```bash
# Force ImageRepository to check Docker Hub
kubectl annotate imagerepository -n flux-system intikepri-static reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate imagerepository -n flux-system intikepri-cms reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux

# Force ImagePolicy to re-evaluate tag ordering
kubectl annotate imagepolicy -n flux-system intikepri-static reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate imagepolicy -n flux-system intikepri-cms reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux

# Force ImageUpdateAutomation to commit image updates
kubectl annotate imageupdateautomation -n flux-system intikepri-static reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate imageupdateautomation -n flux-system intikepri-cms reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux

# Force Receiver to process webhook
kubectl annotate receiver -n flux-system intikepri-static-git reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate receiver -n flux-system intikepri-static-image reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate receiver -n flux-system intikepri-cms-git reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate receiver -n flux-system intikepri-cms-image reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
kubectl annotate receiver -n flux-system intikepri-infra-webhook reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux
```

If any of these fail to reconcile, check status:

```bash
kubectl describe imagerepository -n flux-system intikepri-cms
kubectl describe imagepolicy -n flux-system intikepri-cms
kubectl describe imageupdateautomation -n flux-system intikepri-cms
kubectl describe receiver -n flux-system intikepri-cms-git
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
