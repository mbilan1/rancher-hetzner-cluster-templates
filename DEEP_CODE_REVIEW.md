# Deep Code Review: rancher-hetzner-cluster-templates

**Date**: 2026-03-07
**Reviewer**: Automated Deep Review (Claude)
**Overall Score**: 7/10

## Executive Summary

Helm chart for Rancher downstream cluster provisioning on Hetzner Cloud. Good CRD integration and security-first defaults, but significant gaps in validation, documentation consistency, and operational guidance.

**Total Issues: 34** — 1 Critical, 2 High, 21 Medium, 10 Low

---

## Critical Issue

### 1. Token Exposure in Manifest StringData

- **File**: `charts/templates/cluster.yaml:149-150`
- HCLOUD_TOKEN embedded in `additionalManifest` using `stringData`. Visible in helm release history, logs, and audit trails via `helm get values`.
- **Fix**: Use RBAC to restrict helm history access; document that `hcloud.token` should only be set by cluster admins.

---

## High Severity Issues

### 2. CCM Version Lacks Validation

- **File**: `charts/values.yaml:121`
- CCM version is pinned to exact version `"1.30.1"` (static string passed to HelmChart CRD `version` field), but there is no semver format validation in `values.schema.json` or `questions.yaml` to prevent operators from entering invalid version strings.
- **Fix**: Add version format validation (e.g., via `values.schema.json` pattern or `questions.yaml` validation).

### 3. Server Location Default Inconsistency

- **File**: `charts/templates/nodeconfig-hetzner.yaml:26`
- Template defaults to `"nbg1"`, but `values.yaml:71` and `questions.yaml:154` default to `"hel1"`.
- **Impact**: Nodes may be created in unexpected regions.
- **Fix**: Change template default from `"nbg1"` to `"hel1"`.

---

## Medium Severity Issues (22 total, key highlights)

### Security (4)
- **Token scope validation gap** (`values.yaml:32`) — No documentation warning that `cloudCredentialSecretName` and `hcloud.token` should reference the same Hetzner project. Note: this cannot be validated at Helm render time (no API access); reframed as a documentation gap.
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
- ~~**Network CIDR sync dependency**~~ — *Removed: not a real issue.* Both `machineGlobalConfig` (line 105) and CCM `valuesContent` (line 169) reference the same Helm value (`{{ .Values.clusterConfig.clusterCIDR | default "10.42.0.0/16" }}`), so they are guaranteed to stay in sync.

### Other (4)
- **No resource limits for system components** — No `systemReserved`/`kubeReserved` configuration.
- **No RBAC validation for ClusterRoleTemplateBinding** — Accepts any `clusterMembers` without format validation.
- **Firewall auto-creation without explicit ACL** (`values.yaml:76-77`) — No granular control over auto-created firewall rules.

---

## Low Severity Issues (11)

- `agentEnvs` not exposed in questions.yaml (proxy config hidden)
- `cisPackerReference` helper in `_helpers.tpl:47-67` — intentionally not invoked; serves as reference documentation for Packer image requirements (see `_helpers.tpl:36` comment)
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
- Kubernetes Secrets used for token storage (note: token is still exposed via `additionalManifest` `stringData` as flagged in Critical Issue #1 — the Secret itself is correct, but the delivery mechanism has exposure risk)
- Firewall delegation to driver (not hardcoded)
- Clear CRD integration (provisioning.cattle.io/v1, rke-machine-config.cattle.io/v1)
- Cloud credential pattern via Rancher's system
- Extensive DECISION comments explaining design choices

---

## Maintenance Note

> This static review document will become stale as issues are addressed. Consider converting actionable findings into GitHub Issues with appropriate labels/severity for better tracking of resolution status.

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
| Infrastructure (3) | 0 | 3 | Single pool, drain disabled, CRTB hash |
| Other (3) | 0 | 3 | Resource limits, RBAC validation, firewall ACL |

### Low Issues (10 total): 0 fixed

### Additional fixes applied (beyond review scope)
- caCerts/fqdn quoting in cluster.yaml (proper YAML output)
- CCM + external cloudProviderName deadlock guard (fail template)
- Icon field added to Chart.yaml
- YAML document-start markers added

**Summary**: 1/34 fully fixed (location default, with branch fix), 0 partial on medium/low, 33 remaining. (2 issues removed per Copilot review: duplicate cloudCredentialSecretName, false-positive Network CIDR sync.)
