# Bootstrap

OpenShift platform bootstrap repository — provisions two sovereign clusters end-to-end using GitOps (ArgoCD) and RHACM for multi-cluster management.

---

## Prerequisites

### 1. Environment Variables

All variables below **must** be exported in your shell before running any `make` target.
Run `make check-env` to verify all 12 are set and test logins.

#### Central Cluster (OpenShift)

| Variable | Description |
|---|---|
| `OCP_CENTRAL_SERVER` | API server URL (e.g. `https://api.central.example.com:6443`) |
| `OCP_CENTRAL_USERNAME` | OpenShift username |
| `OCP_CENTRAL_PASSWORD` | OpenShift password |

#### Services Cluster (OpenShift)

| Variable | Description |
|---|---|
| `OCP_SERVICES_SERVER` | API server URL (e.g. `https://api.services.example.com:6443`) |
| `OCP_SERVICES_USERNAME` | OpenShift username |
| `OCP_SERVICES_PASSWORD` | OpenShift password |

#### OCI / Quay Registry — Admin Token

| Variable | Description |
|---|---|
| `OCI_REGISTRY` | Registry URL or hostname (e.g. `https://quay.io/organization/myorg` or `quay.io`) |
| `OCI_REGISTRY_TOKEN` | Admin bearer token — used to create OCI repositories |

#### OCI / Quay Registry — Robot (Pull/Push) Account

| Variable | Description |
|---|---|
| `OCI_ROBOT_USERNAME` | Robot account username (e.g. `myorg+pull`) |
| `OCI_ROBOT_PASSWORD` | Robot account token |

#### Git

| Variable | Description |
|---|---|
| `GITHUB_URL` | Repository base URL (e.g. `https://github.com/my-org/bootstrap`) |
| `GITHUB_TOKEN` | Personal access token with `repo` scope |

### 2. Cluster Requirements

Each OpenShift cluster must have the following installed **before** running the bootstrap:

| Requirement | Notes |
|---|---|
| **OpenShift 4.x** | Both `central` and `services` clusters |
| **ArgoCD (OpenShift GitOps)** | Installed and accessible |

> These are one-time manual installs per cluster. Everything after `make init-central-argo` is ArgoCD-driven.

### 3. Quay Robot Account

The OCI robot account must exist in your Quay organization with **admin** permissions on the chart repository. `make upload-acm-chart` will create the repository if it doesn't exist. A default permission prototype in the org ensures the robot gets access to new repos automatically.

---

## Quick Start

```bash
# 1. Export all 12 required env vars
export OCP_CENTRAL_SERVER=https://api.central.example.com:6443
export OCP_CENTRAL_USERNAME=admin
export OCP_CENTRAL_PASSWORD=...
# ... (remaining vars)

# 2. Verify all env vars + test logins
make check-env

# 3. Push the RHACM Helm chart to the OCI registry
make upload-acm-chart

# 4. Bootstrap ArgoCD on the central cluster
make init-central-argo
```

---

## Make Targets

| Target | Description |
|---|---|
| `make check-env` | Verify all 12 env vars + test OCP and OCI logins |
| `make upload-acm-chart` | Create the OCI repository and push the RHACM Helm chart |
| `make init-central-argo` | Log in to central cluster, deploy `helm/init`, trigger the ApplicationSet |
| `make help` | Show all targets with descriptions |

---

## Folder Layout

```
bootstrap/
├── Makefile              # Thin importer — includes all make/*.mk
├── make/                 # Individual make target files
│   ├── check-env.mk
│   ├── upload-acm-chart.mk
│   ├── init-central-argo.mk
│   └── help.mk
└── helm/
    ├── charts/
    │   └── rhacm/        # Standalone RHACM operator chart — pushed to OCI
    ├── central/          # App-of-Apps chart for the central cluster
    └── init/             # Bootstrap entry-point chart
                          #   creates: ApplicationSet, git secret, services cluster secret
```

### Directory Details

| Path | Purpose |
|---|---|
| `make/` | Each make target in its own `.mk` file for maintainability |
| `helm/charts/rhacm` | Self-contained Helm chart for RHACM. Pushed to OCI by `make upload-acm-chart`. |
| `helm/central` | App-of-Apps chart for the **central** cluster. Contains an ArgoCD `Application` per platform component. |
| `helm/init` | Bootstrap entry-point. Creates the ArgoCD `ApplicationSet` that renders app-of-apps, registers the git repo credential, and registers the services cluster with ArgoCD. |

---

## Derived Variables

The Makefile automatically derives from `OCI_REGISTRY`:

| Variable | Derivation | Example |
|---|---|---|
| `OCI_HOST` | Hostname extracted from URL | `quay.signal9.gg` |
| `OCI_NAMESPACE` | Organization from URL path | `hybrid-sovereign` |

If `OCI_REGISTRY` is just a hostname (no path), `OCI_NAMESPACE` defaults to `sovereign`.

---

## Architecture

See [`architecture/docs/architecture.md`](../architecture/docs/architecture.md) for:
- Cluster topology diagram (Mermaid)
- Bootstrap sequence diagram (Mermaid)
- Component responsibilities
- Secrets strategy

## Security Assessment

See [`architecture/hardeningcheck/security-assessment.md`](../architecture/hardeningcheck/security-assessment.md) for:
- Threat model
- Hardening checks (pass/fail/todo)
- CIS benchmark gaps
- Remediation priority list
