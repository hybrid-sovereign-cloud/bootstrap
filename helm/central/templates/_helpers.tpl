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
OCI chart URL helper: oci://<registry>/<repositoryBase>/<chartName>
For ArgoCD v3.x, the repoURL must include the full path to the chart.
*/}}
{{- define "sovereign-central.ociURL" -}}
{{- printf "oci://%s/%s/rhacm" .Values.oci.registry .Values.oci.repositoryBase }}
{{- end }}
