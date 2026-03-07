# Deep Code Review: rancher-hetzner-cluster-templates

**Date**: 2026-03-07
**Reviewer**: Automated Deep Review (Claude)
**Overall Score**: 7/10

## Executive Summary

Helm chart for Rancher downstream cluster provisioning on Hetzner Cloud. Good CRD integration and security-first defaults, but significant gaps in validation, documentation consistency, and operational guidance.

**Total Issues: 36** — 1 Critical, 2 High, 22 Medium, 11 Low

---

## Critical Issue

### 1. Token Exposure in Manifest StringData

- **File**: `charts/templates/cluster.yaml:149-150`
- HCLOUD_TOKEN embedded in `additionalManifest` using `stringData`. Visible in helm release history, logs, and audit trails via `helm get values`.
- **Fix**: Use RBAC to restrict helm history access; document that `hcloud.token` should only be set by cluster admins.

---

## High Severity Issues

### 2. Unconstrained CCM Version

- **File**: `charts/values.yaml:121`
- CCM version defaults to `"1.30.1"` with no semver constraints or validation. Uncontrolled updates can break cluster networking.
- **Fix**: Pin to exact versions; add version validation.

### 3. Server Location Default Inconsistency

- **File**: `charts/templates/nodeconfig-hetzner.yaml:26`
- Template defaults to `"nbg1"`, but `values.yaml:71` and `questions.yaml:154` default to `"hel1"`.
- **Impact**: Nodes may be created in unexpected regions.
- **Fix**: Change template default from `"nbg1"` to `"hel1"`.

---

## Medium Severity Issues (22 total, key highlights)

### Security (4)
- **Token scope validation missing** (`values.yaml:32`) — No check that `cloudCredentialSecretName` and `hcloud.token` use the same Hetzner project.
- **SSH key rotation policy absent** (`values.yaml:83`) — No guidance on key rotation or minimum strength.
- **CIS hardening disabled by default** (`values.yaml:150`) — Production clusters without CIS have elevated privilege defaults.
- **Network policy enabled but not enforced** (`cluster.yaml:40`) — `enableNetworkPolicy: true` set but Canal doesn't enforce without explicit policies. False sense of security.

### Validation (5)
- **No values.schema.json** — Helm 3.7+ supports JSON Schema; invalid values only fail at Rancher runtime.
- **No autoscaler minSize ≤ quantity validation** (`questions.yaml:100-107`) — Invalid configs pass form but fail at runtime.
- **Missing cloudCredentialSecretName required check** (`cluster.yaml:36-38`) — Uses `if` instead of `required`, creating Cluster CRD without credentials.
- **CIDR overlap not validated** (`questions.yaml:258-270`) — Cluster/Service/Network CIDRs can overlap, breaking pod routing.
- **Hetzner network name not validated** (`questions.yaml:48-53`) — Any string accepted, fails at API level.

### Documentation (5)
- **Contradictory manual secret creation** (`docs/USAGE.md:103-114`) — Doc says create secret manually, but chart does it automatically via `additionalManifest`.
- **ADR/DES references not accessible** (multiple files) — References external architecture repo without links.
- **CIS hardening image requirement unclear** (`docs/USAGE.md:57-85`) — CIS enabled without Packer image causes silent bootstrap failure.
- **No multiple node pools example** — Chart supports `nodepools[]` array but shows only single-pool examples.
- **No etcd backup strategy** — No RKE2 etcd snapshot configuration or DR guidance.

### Infrastructure (4)
- **Single converged node pool default** (`values.yaml:60-95`) — All roles on 3 nodes; workloads can starve control plane.
- **Upgrade drain options disabled** (`values.yaml:165-170`) — Pods not gracefully evicted during upgrades.
- **ClusterRoleTemplateBinding fragile hash** (`clusterroletemplatebinding.yaml:15-19`) — `sha256sum` truncated to 8 chars creates collision risk.
- **Network CIDR sync dependency** (`cluster.yaml:105,169`) — Cluster CIDR must match between RKE2 config and CCM values.

### Other (4)
- **No resource limits for system components** — No `systemReserved`/`kubeReserved` configuration.
- **No RBAC validation for ClusterRoleTemplateBinding** — Accepts any `clusterMembers` without format validation.
- **Firewall auto-creation without explicit ACL** (`values.yaml:76-77`) — No granular control over auto-created firewall rules.
- **Missing required cloudCredentialSecretName** (`cluster.yaml:36-38`) — Template renders silently without credentials.

---

## Low Severity Issues (11)

- `agentEnvs` not exposed in questions.yaml (proxy config hidden)
- Unused `cisPackerReference` helper in `_helpers.tpl:47-67`
- Incomplete local auth endpoint documentation (`questions.yaml:309-313`)
- Secrets encryption enabled but no key rotation documentation
- No health checks or readiness probe configuration
- No Helm version constraint in `Chart.yaml`
- No CHANGELOG for version tracking
- Limited RKE2 version choices (only 3 versions offered)
- Potential YAML escaping in `additionalManifest`
- Inconsistent `| default` usage across templates
- Fail conditions only checked at template render, not install

---

## Strengths

- Excellent architectural documentation (CLAUDE.md)
- Strategic fail conditions for critical misconfigurations (CCM + external provider deadlock)
- Security-first defaults (secrets encryption enabled, network policies enabled)
- Proper Kubernetes Secrets usage for token storage
- Firewall delegation to driver (not hardcoded)
- Clear CRD integration (provisioning.cattle.io/v1, rke-machine-config.cattle.io/v1)
- Cloud credential pattern via Rancher's system
- Extensive DECISION comments explaining design choices

---

## Fix Verification Status (2026-03-07)

Verified against commit `0b6f913` ("fix: resolve code review findings") on `main` + additional fix in this branch.

| # | Issue | Severity | Status | Notes |
|---|-------|----------|--------|-------|
| 1 | Token exposure in stringData | Critical | **NOT FIXED** | hcloud.token still in additionalManifest stringData |
| 2 | Unconstrained CCM version | High | **NOT FIXED** | No semver validation added |
| 3 | Server location default inconsistency | High | **FIXED** | values.yaml/questions.yaml aligned to hel1; **nodeconfig-hetzner.yaml fixed in this branch** (was "nbg1", now "hel1") |

### Medium Issues (22 total)

| Category | Fixed | Not Fixed | Details |
|----------|-------|-----------|---------|
| Security (4) | 0 | 4 | Token scope, SSH rotation, CIS default, NetworkPolicy |
| Validation (5) | 0 | 5 | No schema, no minSize check, no required credential, no CIDR overlap, no network validation |
| Documentation (5) | 0 | 5 | Contradictory manual secret, ADR links, CIS image, multi-pool, etcd backup |
| Infrastructure (4) | 0 | 4 | Single pool, drain disabled, CRTB hash, CIDR sync |
| Other (4) | 0 | 4 | Resource limits, RBAC validation, firewall ACL, credential required |

### Low Issues (11 total): 0 fixed

### Additional fixes applied (beyond review scope)
- caCerts/fqdn quoting in cluster.yaml (proper YAML output)
- CCM + external cloudProviderName deadlock guard (fail template)
- Icon field added to Chart.yaml
- YAML document-start markers added

**Summary**: 1/36 fully fixed (location default, with branch fix), 0 partial on medium/low, 35 remaining.
