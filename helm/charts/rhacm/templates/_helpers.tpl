{{/*
Chart name
*/}}
{{- define "rhacm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rhacm.labels" -}}
helm.sh/chart: {{ include "rhacm.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "rhacm.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: sovereign-bootstrap
app.kubernetes.io/component: rhacm
{{- end }}

{{/*
Namespace helper
*/}}
{{- define "rhacm.namespace" -}}
{{- .Values.namespace.name }}
{{- end }}
