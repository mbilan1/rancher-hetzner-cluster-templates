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
