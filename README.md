# Bootstrap

OpenShift platform bootstrap repository — provisions two sovereign clusters end-to-end using GitOps (ArgoCD) and RHACM for multi-cluster management.

---

## Prerequisites

### 1. Environment Variables

All variables below **must** be exported in your shell before running any `make` target.
Run `make check-env` to verify they are set and test logins.

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
| `OCI_REGISTRY_TOKEN` | Admin bearer token — used to create OCI repositories and push |

#### OCI / Quay Registry — Robot (Read-Only)

| Variable | Description |
|---|---|
| `OCI_ROBOT_USERNAME` | Robot account username (e.g. `myorg+pull`) — read-only |
| `OCI_ROBOT_PASSWORD` | Robot account token |

#### Image Registry (Red Hat)

| Variable | Description |
|---|---|
| `IMAGE_REGISTRY` | Container image registry (e.g. `registry.redhat.io`) |
| `IMAGE_REGISTRY_USERNAME` | Registry login username |
| `IMAGE_REGISTRY_PASSWORD` | Registry login password/token |

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

The OCI robot account (`hybrid-sovereign+pull`) has **read-only** access on all repositories in the organization. The admin token (`OCI_REGISTRY_TOKEN`) is used for all write operations.

---

## Make Targets

### Check Bastion Configs

| Target | Description |
|---|---|
| `make check-env` | Verify all required env vars + test OCP and OCI logins |
| `make add-docker-repo` | Trust `IMAGE_REGISTRY` on both clusters (create pull secret) |

### Build Artifacts

| Target | Description |
|---|---|
| `make upload-acm-chart` | Create OCI repo + push RHACM Helm chart |
| `make upload-sovereign-namespaces-chart` | Create OCI repo + push sovereign-namespaces chart |
| `make upload-rhbk-chart` | Create OCI repo + push RHBK (Keycloak) chart |
| `make ansible-runner` | Build ansible-runner image + push to Quay |

### Bootstrap Cluster

| Target | Description |
|---|---|
| `make init-central-argo` | Deploy `helm/init`, trigger ApplicationSet for both clusters |

---

## Execution Order

```
# 1. Check bastion configs
make check-env              ← validate env vars + test logins
make add-docker-repo        ← trust image registry on both clusters

# 2. Build artifacts
make upload-acm-chart       ← push RHACM chart to OCI
make upload-sovereign-namespaces-chart  ← push namespace chart to OCI
make upload-rhbk-chart      ← push Keycloak chart to OCI
make ansible-runner         ← build and push ansible-runner image

# 3. Bootstrap cluster
make init-central-argo      ← deploy init chart → ArgoCD takes over
```

---

## Folder Layout

```
bootstrap/
├── Makefile              # Thin importer — includes all make/*.mk
├── make/                 # Individual make target files
│   ├── check-env.mk
│   ├── add-docker-repo.mk
│   ├── upload-acm-chart.mk
│   ├── upload-sovereign-namespaces-chart.mk
│   ├── upload-rhbk-chart.mk
│   ├── ansible-runner.mk
│   ├── init-central-argo.mk
│   └── help.mk
├── helm/
│   ├── charts/
│   │   ├── rhacm/                  # RHACM operator chart (OCI)
│   │   ├── sovereign-namespaces/   # Namespace creation chart (OCI)
│   │   └── rhbk/                   # Keycloak operator chart (OCI)
│   ├── central/                    # App-of-Apps for central cluster
│   ├── services/                   # App-of-Apps for services cluster
│   └── init/                       # Bootstrap entry-point chart
└── ansible/
    ├── imagebuild/
    │   └── ansiblerunner/          # Containerfile for ansible-runner image
    ├── roles/
    │   ├── keycloak-realms/        # Create realms in Keycloak
    │   ├── keycloak-clients/       # Create clients + copy secrets
    │   ├── keycloak-oauth/         # Configure OAuth on clusters
    │   └── keycloak-rbac/          # Create admin group + RBAC bindings
    └── project/
        └── configure-keycloak.yml  # Main playbook
```

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
- Cluster topology diagrams
- Bootstrap sequence
- Component responsibilities
- Secrets strategy

Bootstrap-aligned technical supplements (waves, tenancy stack):

- [`architecture/docs/technical/18-secrets-flow.md`](architecture/docs/technical/18-secrets-flow.md) — vault / ESO choreography (includes **helm/central** sync waves)
- [`architecture/docs/technical/20-tenancy-operators.md`](architecture/docs/technical/20-tenancy-operators.md) — tenancy **Ansible** operators (`Team`, `Assignment`, `Project`, `PlatformOpenshift`, `CloudOSO`)
- [`architecture/docs/technical/21-prometheus-metrics.md`](architecture/docs/technical/21-prometheus-metrics.md) — `8443` metrics, `ServiceMonitor`, `PrometheusRule` alerts

## Security Assessment

See [`architecture/hardeningcheck/security-assessment.md`](../architecture/hardeningcheck/security-assessment.md) for:
- Threat model
- Hardening checks (pass/fail/todo)
- CIS benchmark gaps
- Remediation priority list

Tenancy operator hardening addendum: [`architecture/hardeningcheck/tenancy-operators.md`](architecture/hardeningcheck/tenancy-operators.md)
