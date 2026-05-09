{{/*
Expand the name of the chart.
*/}}
{{- define "sovereign-init.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sovereign-init.labels" -}}
helm.sh/chart: {{ include "sovereign-init.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "sovereign-init.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: sovereign-bootstrap
{{- end }}
