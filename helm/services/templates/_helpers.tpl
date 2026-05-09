{{/*
Chart name
*/}}
{{- define "sovereign-services.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sovereign-services.labels" -}}
helm.sh/chart: {{ include "sovereign-services.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "sovereign-services.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: sovereign-bootstrap
{{- end }}

{{/*
OCI chart URL helper
*/}}
{{- define "sovereign-services.ociURL" -}}
{{- printf "oci://%s/%s" .Values.oci.registry .Values.oci.repositoryBase }}
{{- end }}
