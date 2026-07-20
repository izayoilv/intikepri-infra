# intikepri-infra

Infrastructure repository for the intikepri project. Manages Kubernetes cluster resources and OpenTofu configurations for intikepri.com.

Managed by Flux via the [kudofools-infra](https://forgejo.kudofools.dev/izayoilv/kudofools-infra) GitRepository source.

## Structure

```
clusters/default/
├── infra/
│   ├── system/               # Namespaces, LimitRanges, NetworkPolicies, PVCs
│   ├── platform/
│   │   ├── ingress/          # Traefik Middlewares
│   │   └── cloudflared/      # Cloudflare Tunnel deployment + RBAC
│   │                           (ConfigMap & credentials Secret managed by OpenTofu)
│   └── apps/
│       └── openbao/          # OpenBao StatefulSet + Service + Ingress
├── platform/
│   └── eso-resources/        # ClusterSecretStore + ExternalSecrets
│                               (uses kudofools-infra's ESO)
└── opentofu/                  # OpenTofu IaC (applied by tofu-controller)
    ├── main.tf               # Provider configs
    ├── cloudflare.tf         # Tunnel, credentials Secret, DNS records
    ├── openbao.tf            # OpenBao mounts, policies, auth config
    └── variables.tf          # Input variables
```
