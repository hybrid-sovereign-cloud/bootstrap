{{/*
Chart name
*/}}
{{- define "sovereign-central.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sovereign-central.labels" -}}
helm.sh/chart: {{ include "sovereign-central.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "sovereign-central.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: sovereign-bootstrap
{{- end }}

{{/*
OCI chart URL helper: oci://<registry>/<repositoryBase>
ArgoCD appends the chart name from spec.source.chart to this base URL.
*/}}
{{- define "sovereign-central.ociURL" -}}
{{- printf "oci://%s/%s" .Values.oci.registry .Values.oci.repositoryBase }}
{{- end }}
