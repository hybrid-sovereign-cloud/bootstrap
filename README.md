# Hybrid Sovereign Cloud Bootstrap

Bootstraps a sovereign cloud control plane on OpenShift via Helm-only deployments.

## Prerequisites

- OpenShift cluster access (ROSA/OCP)
- `oc`, `helm`, `git`, `make` CLIs
- Environment variables:

```bash
export OCP_SERVER=https://api.xxxxxxxxxxxxxx:6443
export OCP_USERNAME=xxxxxxxxxxxxx
export OCP_PASSWORD=xxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Quick Start

```bash
# Login
make login

# Import repos
make import-architecture
make import-initrepos

# Install operators (OLM subscriptions)
make install-all-operators
make approve-rhbk-installplan

# Install instances
make install-all-instances

# Configure Vault
make vault-init

# Configure Keycloak
make keycloak-config

# Configure External Secrets
make external-secrets-config

# Install ODF + object storage
make install-odf-operator
make install-odf-noobaa

# Install Quay
make install-quay-instance

# Check status
make status
```

## Repository Layout

```
bootstrap/
├── charts/
│   ├── operators/              # OLM Subscription charts
│   │   ├── aap-operator/
│   │   ├── external-secrets-operator/
│   │   ├── rhbk-operator/
│   │   ├── gitops-operator/
│   │   ├── quay-operator/
│   │   └── odf-operator/
│   ├── instances/              # Operand/instance charts
│   │   ├── aap-instance/
│   │   ├── vault-instance/
│   │   ├── rhbk-instance/
│   │   ├── gitops-instance/
│   │   ├── gitea-instance/
│   │   ├── sovereign-cloud/
│   │   ├── quay-instance/
│   │   └── odf-noobaa/
│   └── config/                 # Configuration charts
│       ├── vault-init/
│       ├── keycloak-config/
│       └── external-secrets-config/
├── design/architecture/        # Architecture docs (imported)
├── init/base_chart/            # Legacy base chart (imported)
├── Makefile
├── CLAUDE.md
├── .cursor/rules/
└── .cursorrules
```

## Namespace Map

| Component | Namespace | Type |
|---|---|---|
| AAP Operator | `ansible-automation-platform` | OLM Subscription |
| ESO Operator | `external-secrets-operator` | OLM Subscription |
| RHBK Operator + Instance | `rhbk` | OLM + Keycloak CR |
| GitOps Operator | `openshift-gitops` | OLM Subscription |
| Quay Operator + Instance | `quay` | OLM + QuayRegistry CR |
| ODF Operator + NooBaa | `openshift-storage` | OLM + NooBaa CR |
| Vault Instance + Init | `vault` | Helm chart |
| AAP Instance | `aap` | AnsibleAutomationPlatform CR |
| Sovereign Cloud | `sovereign-cloud` | Foundation namespace |

## Makefile Targets

Run `make help` for all targets.

## Rules

- All deployments use **Helm only** (no `oc create/apply/patch` in Makefile)
- `oc` commands for **investigation only**
- Use **podman** for container builds
- Use **ImageStreams** for image uploads
- Every change must update `design/architecture/`
