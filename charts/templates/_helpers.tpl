{{/*
────────────────────────────────────────────────────────────────────────────────
Hetzner RKE2 Cluster Template — Helpers
────────────────────────────────────────────────────────────────────────────────
*/}}

{{/*
Chart name (truncated to 63 chars for K8s label compliance).
*/}}
{{- define "hetzner-cluster-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full cluster name — used as the primary resource name.
*/}}
{{- define "hetzner-cluster-template.clusterName" -}}
{{- required "cluster.name is required" .Values.cluster.name }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "hetzner-cluster-template.labels" -}}
helm.sh/chart: {{ include "hetzner-cluster-template.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: rancher-hetzner-cluster-templates
{{- end }}

{{/*
────────────────────────────────────────────────────────────────────────────────
Cluster Autoscaler — cloud-init for RKE2 agent bootstrap

Generates a cloud-init script that:
  1. Installs RKE2 agent binary
  2. Configures it to join the cluster (server URL + token)
  3. Sets cloud-provider-name: external (required for Hetzner CCM)
  4. Labels the node as autoscaler-managed for scheduling/identification
  5. Starts the rke2-agent systemd service

The output of this helper is base64-encoded and passed to the Hetzner CA
via the HCLOUD_CLOUD_INIT environment variable.
────────────────────────────────────────────────────────────────────────────────
*/}}
{{- define "hetzner-cluster-template.autoscalerCloudInit" -}}
#!/bin/bash
set -euo pipefail

# ── Install RKE2 Agent ────────────────────────────────────────────────────────
{{- if .Values.cluster.kubernetesVersion }}
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION={{ .Values.cluster.kubernetesVersion | quote }} INSTALL_RKE2_TYPE=agent sh -
{{- else }}
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_TYPE=agent sh -
{{- end }}

# ── Configure RKE2 Agent ──────────────────────────────────────────────────────
mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<'RKEEOF'
server: {{ required "autoscaler.rke2.serverUrl is required when autoscaler is enabled" .Values.autoscaler.rke2.serverUrl }}
token: {{ required "autoscaler.rke2.joinToken is required when autoscaler is enabled" .Values.autoscaler.rke2.joinToken }}
cloud-provider-name: external
node-label:
  - node.kubernetes.io/role=autoscaler
  - autoscaler.kubernetes.io/managed=true
RKEEOF

# ── Start RKE2 Agent ──────────────────────────────────────────────────────────
systemctl enable rke2-agent.service
systemctl start rke2-agent.service
{{- end }}
