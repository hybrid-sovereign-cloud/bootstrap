#!/usr/bin/env bash
# make-pipelinerun.sh — emit a Tekton PipelineRun manifest to stdout.
# Usage: make-pipelinerun.sh <pipeline-name> <namespace> <image-tag>
set -euo pipefail

PIPELINE="${1:?pipeline name required}"
NS="${2:-sovereign-cloud}"
TAG="${3:-latest}"

cat <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${PIPELINE}-run-
  namespace: ${NS}
  labels:
    operator-pipeline: "${PIPELINE}"
spec:
  pipelineRef:
    name: ${PIPELINE}
  params:
    - name: image-tag
      value: "${TAG}"
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 2Gi
    - name: git-credentials
      secret:
        secretName: github-basic-auth
YAML
