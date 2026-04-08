# Hetzner RKE2 Cluster Template

[![Lint: Helm](https://github.com/mbilan1/rancher-hetzner-cluster-templates/actions/workflows/lint-helm.yml/badge.svg)](https://github.com/mbilan1/rancher-hetzner-cluster-templates/actions/workflows/lint-helm.yml)
[![SAST: Checkov](https://github.com/mbilan1/rancher-hetzner-cluster-templates/actions/workflows/sast-checkov.yml/badge.svg)](https://github.com/mbilan1/rancher-hetzner-cluster-templates/actions/workflows/sast-checkov.yml)
[![SAST: KICS](https://github.com/mbilan1/rancher-hetzner-cluster-templates/actions/workflows/sast-kics.yml/badge.svg)](https://github.com/mbilan1/rancher-hetzner-cluster-templates/actions/workflows/sast-kics.yml)

<!-- Version badges — source: charts/Chart.yaml (version), charts/values.yaml (kubernetesVersion) -->
![Chart](https://img.shields.io/badge/Chart-0.1.0-0F1689?logo=helm&logoColor=white)
![RKE2](https://img.shields.io/badge/RKE2-v1.35.3%2Brke2r1-0075A8?logo=kubernetes&logoColor=white)

> **⚠️ Experimental (Beta)** — This is an **unofficial** community implementation, under active development and **not production-ready**.
> APIs, values schema, and behavior may change without notice. Use at your own risk.
> No stability guarantees are provided until v1.0.0.

Rancher Cluster Template for provisioning RKE2 Kubernetes clusters on Hetzner Cloud.

## Ecosystem

This chart is part of the **RKE2-on-Hetzner** ecosystem — a set of interconnected projects that together provide a complete Kubernetes management platform on Hetzner Cloud.

| Repository | Role in Ecosystem |
|---|---|
| [`terraform-hcloud-rke2-core`](https://github.com/mbilan1/terraform-hcloud-rke2-core) | L3 infrastructure primitive — servers, network, readiness |
| [`terraform-hcloud-rancher`](https://github.com/mbilan1/terraform-hcloud-rancher) | Management cluster — Rancher + Node Driver on RKE2 |
| **`rancher-hetzner-cluster-templates`** (this repo) | **Downstream cluster provisioning via Rancher UI** |
| [`packer-hcloud-rke2`](https://github.com/mbilan1/packer-hcloud-rke2) | Packer node image — CIS-hardened snapshots |

```
rke2-core (L3 infra) → rancher (L3+L4 management) → cluster-templates (downstream via UI)
                                                    ↑
                                        packer (node images)
```

## What This Does

Registers as a chart repository in Rancher and enables one-click downstream cluster creation:

1. **Rancher UI** → Create Cluster → Select "Hetzner Cloud (RKE2)"
2. **Fill form** — cluster name, credentials, node pool config
3. **Click Create** — Rancher provisions Hetzner servers, installs RKE2, deploys CCM

## Architecture

```
terraform-hcloud-rancher (tofu apply)
  → Management cluster with Rancher + Hetzner Node Driver
  → output: network_id, rancher_url

rancher-hetzner-cluster-templates (this repo)
  → Chart Repository registered in Rancher
  → Cluster Template with Hetzner-optimized defaults
  → CCM deployed via additionalManifest (RKE2 HelmChart CRD)
```

Architecture decisions: ADR-004 (Downstream Provisioning), DES-001 (Cluster Template Helm Chart).

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
    ├── clusterroletemplatebinding.yaml # Rancher RBAC bindings
    └── nodeconfig-hetzner.yaml # rke-machine-config.cattle.io/v1 HetznerConfig
```

## Node Driver

Uses [zsys-studio/rancher-hetzner-cluster-provider](https://github.com/zsys-studio/rancher-hetzner-cluster-provider) v0.9.0 (Apache-2.0).

## License

MIT
