#!/usr/bin/env bash
# apply-argoapp.sh — Create or update an ArgoCD Application pointing to an OCI Helm chart.
#
# Usage:
#   apply-argoapp.sh <app-name> <chart-name> <namespace> <wave> [key=value ...]
#
# Extra key=value pairs are passed as Helm parameters in the Application spec.
# Special keys: SYNC_POLICY_NONE=1 disables automated sync (manual only).
#
# Env vars honoured:
#   OCI_HELM_REGISTRY  — default: oci://quay.io/sovereignhybrid
#   CHART_VERSION      — default: 0.1.0

set -euo pipefail

APP_NAME="${1:?app-name required}"
CHART_NAME="${2:?chart-name required}"
NAMESPACE="${3:?namespace required}"
WAVE="${4:?wave required}"
shift 4

OCI_HELM_REGISTRY="${OCI_HELM_REGISTRY:-oci://quay.io/sovereignhybrid}"
CHART_VERSION="${CHART_VERSION:-0.1.0}"

# Build helm parameters block
HELM_PARAMS_YAML=""
for kv in "$@"; do
  key="${kv%%=*}"
  val="${kv#*=}"
  HELM_PARAMS_YAML="${HELM_PARAMS_YAML}        - name: ${key}
          value: \"${val}\"
"
done

if [ -n "$HELM_PARAMS_YAML" ]; then
  HELM_SECTION="      parameters:
${HELM_PARAMS_YAML}"
else
  HELM_SECTION=""
fi

cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "${WAVE}"
  labels:
    app.kubernetes.io/managed-by: sovereign-bootstrap
spec:
  project: default
  source:
    chart: ${CHART_NAME}
    repoURL: ${OCI_HELM_REGISTRY}/${CHART_NAME}
    targetRevision: "${CHART_VERSION}"
    helm:
      releaseName: ${APP_NAME}
${HELM_SECTION}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
      - SkipDryRunOnMissingResource=true
EOF

echo "==> Application '${APP_NAME}' applied (OCI chart: ${OCI_HELM_REGISTRY}/${CHART_NAME}:${CHART_VERSION})"
