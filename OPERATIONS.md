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
