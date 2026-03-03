# Claude Instructions — rancher-hetzner-cluster-templates

> Single source of truth for AI agents working on this repository.
> AGENTS.md redirects here. Read this file in full before any task.

---

## Identity

**Rancher Cluster Template** — Helm chart for provisioning downstream RKE2 clusters
on Hetzner Cloud via the Rancher UI. Outputs `provisioning.cattle.io/v1 Cluster`
and `rke-machine-config.cattle.io/v1 HetznerConfig` CRDs.

---

## Sibling Repositories

| Repo | Local Path | Purpose |
|---|---|---|
| `terraform-hcloud-rke2-core` | `/home/mbilan/workdir/astract/terraform-hcloud-rke2-core` | L3 infrastructure primitive |
| `terraform-hcloud-rancher` | `/home/mbilan/workdir/astract/terraform-hcloud-rancher` | Management cluster (Rancher) |
| `rke2-hetzner-architecture` | `/home/mbilan/workdir/astract/rke2-hetzner-architecture` | Architecture knowledge base |

---

## Critical Rules

### NEVER:
1. Add Terraform code — this is a Helm-only repository
2. Modify CRD apiVersions without checking Rancher compatibility
3. Remove `catalog.cattle.io/type: cluster-template` annotation from Chart.yaml
4. Hardcode HCLOUD_TOKEN values — tokens are delivered via Cloud Credentials
5. Trust training data for Rancher CRD schemas — verify live

### ALWAYS:
1. Run `helm lint ./charts` after any template change
2. Run `helm template test ./charts --set cluster.name=test --set cloudCredentialSecretName=test` to verify rendering
3. Keep CRD field names in camelCase (HetznerConfig uses camelCase, not snake_case)
4. Keep questions.yaml in sync with values.yaml
5. Document manual steps honestly — don't claim automation that doesn't exist

---

## Key Architecture Decisions

- **ADR-004**: Downstream via Rancher Cluster Templates, NOT Terraform
- **ADR-005**: Shared private network between management and downstream
- **INV-002**: zsys-studio driver CRD fields (HetznerConfig)
- **DES-001**: This chart's design document

---

## CRD Reference

### HetznerConfig (rke-machine-config.cattle.io/v1)

Fields are top-level, NOT under `spec`:

```yaml
apiVersion: rke-machine-config.cattle.io/v1
kind: HetznerConfig
metadata:
  name: pool-name
  namespace: fleet-default
serverType: cx23
serverLocation: fsn1
image: ubuntu-24.04
usePrivateNetwork: true
networks:
  - "my-network"
```

### Cluster (provisioning.cattle.io/v1)

Standard Rancher cluster CRD. Key Hetzner-specific config:
- `spec.rkeConfig.machineGlobalConfig.cloud-provider-name: external` (required for CCM)
- `spec.rkeConfig.machinePools[].machineConfigRef.kind: HetznerConfig`

---

## Git Conventions

- **Commits**: `feat|fix|docs(<scope>): <summary>`
- **Scopes**: `chart`, `template`, `values`, `questions`, `docs`
- **Language**: English

---

## Validation Commands

```bash
# Lint chart
helm lint ./charts

# Render templates (dry run)
helm template test ./charts \
  --namespace fleet-default \
  --set cluster.name=test \
  --set cloudCredentialSecretName=test

# Render with custom values
helm template test ./charts \
  --namespace fleet-default \
  --values my-values.yaml
```
