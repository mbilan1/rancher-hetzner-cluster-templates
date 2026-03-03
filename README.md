# Hetzner RKE2 Cluster Template

Rancher Cluster Template for provisioning RKE2 Kubernetes clusters on Hetzner Cloud.

## What This Does

Registers as a chart repository in Rancher and enables one-click downstream cluster creation:

1. **Rancher UI** → Create Cluster → Select "Hetzner Cloud (RKE2)"
2. **Fill form** — cluster name, credentials, node pool config
3. **Click Create** — Rancher provisions Hetzner servers, installs RKE2, deploys CCM/CSI

## Architecture

```
terraform-hcloud-rancher (tofu apply)
  → Management cluster with Rancher + Hetzner Node Driver
  → output: network_id, rancher_url

rancher-hetzner-cluster-templates (this repo)
  → Chart Repository registered in Rancher
  → Cluster Template with Hetzner-optimized defaults
  → ManagedCharts for automatic CCM + CSI deployment
```

Part of the [rke2-hetzner-architecture](https://github.com/mbilan1/rke2-hetzner-architecture) platform:
- [ADR-004: Downstream Provisioning via Rancher Cluster Templates](https://github.com/mbilan1/rke2-hetzner-architecture/blob/main/decisions/adr-004-downstream-provisioning.md)
- [DES-001: Cluster Template Helm Chart](https://github.com/mbilan1/rke2-hetzner-architecture/blob/main/designs/des-001-cluster-template-helm-chart.md)

## Prerequisites

- Rancher management cluster running (via `terraform-hcloud-rancher`)
- Hetzner Node Driver installed (done by `terraform-hcloud-rancher`)
- Hetzner Cloud Credential created in Rancher

## Quick Start

See [docs/USAGE.md](docs/USAGE.md) for the full setup guide.

```bash
# Register in Rancher UI:
# Cluster Management → Advanced → Repositories → Create
# Name: hetzner-templates
# Git Repo URL: https://github.com/mbilan1/rancher-hetzner-cluster-templates.git

# Or via CLI:
helm install my-cluster ./charts \
  --namespace fleet-default \
  --set cluster.name=my-cluster \
  --set cloudCredentialSecretName=cattle-global-data:cc-xxxxx \
  --set hetzner.network=my-network
```

## Chart Structure

```
charts/
├── Chart.yaml                  # Helm metadata + Rancher cluster-template annotations
├── values.yaml                 # Hetzner-optimized defaults
├── questions.yaml              # Rancher UI form definition
└── templates/
    ├── _helpers.tpl            # Template helpers
    ├── cluster.yaml            # provisioning.cattle.io/v1 Cluster CRD
    ├── nodeconfig-hetzner.yaml # rke-machine-config.cattle.io/v1 HetznerConfig
    └── managedcharts.yaml      # CCM + CSI as ManagedChart
```

## Node Driver

Uses [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) v0.8.0 (Apache-2.0).

## License

MIT
