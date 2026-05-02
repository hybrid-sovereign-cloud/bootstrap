# Hybrid Sovereign Cloud Bootstrap

Bootstraps the platform on OpenShift using **Helm** and **make**. The default production path is **GitOps-first**: Phase 1 seeds **OpenShift GitOps** (cluster-scoped), Phase 2 installs an **ApplicationSet** so **Argo CD** owns operators, instances, and config with **selfHeal** and **prune**. **OpenShift Pipelines** and **ImageStreams** cover builds and images.

## Prerequisites

- OpenShift CLI (`oc`), Helm 3, `make`, `git`, `bash`
- Variables — see `.env.example` (copy to `.env`):

| Variable | Purpose |
|----------|---------|
| `OCP_SERVER`, `OCP_USERNAME`, `OCP_PASSWORD` | `make login` |
| `GITHUB_URL` | HTTPS URL of the Git repo that contains this `bootstrap/` tree |
| `GITHUB_TOKEN` | PAT (or token) for Argo to clone / for the post-sync Job |
| `GITHUB_REVISION` | Branch or tag (default `main`) |

### Cursor / agents

- Open the **`bootstrap/`** folder as the workspace so `.cursor/rules/` apply.
- Agents: `CLAUDE.md`, `AGENTS.md`.

### Validate locally (no cluster)

```bash
make validate-helm
```

## GitOps flow (recommended)

### Phase 1 — GitOps operator + Argo repo

Loads `~/.bashrc` when present, then:

```bash
make phase1-gitops
```

Installs the **cluster-scoped** OpenShift GitOps operator, waits for CSV, creates **`platform-git-repository`** (Git credential + `insecure` for TLS), waits for **`ArgoCD/openshift-gitops`**.

### Phase 2 — ApplicationSet (all other charts via Argo)

```bash
make phase2-applicationset
```

Installs Helm release **`platform-applicationset`**, which creates **Applications** for (in sync waves): operators (**not** GitOps — already in phase 1), instances, config charts, and **`argocd-init-job`** (PostSync Job: clone repo + `make argocd-post-sync-waits`).

### One-shot

```bash
make gitops-full-bootstrap
```

### After Git push

Commit/push chart changes, then refresh/sync Applications in Argo (or wait for polling).

### Post-bootstrap: seed Vault secrets

After `phase1-gitops` + `phase2-applicationset`, Vault is unsealed and the KV engine is ready, but application secrets must be seeded before dependent apps (Gitea, Keycloak) start:

```bash
ROOT_TOKEN=$(oc get secret vault-init-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d)
oc exec -n vault central-vault-0 -- sh -c "
  export VAULT_TOKEN='$ROOT_TOKEN'; export VAULT_ADDR=http://127.0.0.1:8200
  vault kv put central/gitea/admin username='sovereign-admin' password='<rotate-me>'
  vault kv put central/keycloak/sovereign-tenants-client \
    client-id='sovereign-tenants' client-secret='<rotate-me>' \
    realm='sovereign-cloud' keycloak-url='https://keycloak-rhbk.<apps-domain>'
"
```

External Secrets Operator will pick up the secrets within `refreshInterval` (1 h) and create the Kubernetes Secrets.

### ROSA / managed-OpenShift note

On ROSA, `openshift-gitops-argocd-application-controller` needs an explicit `cluster-admin` `ClusterRoleBinding` to manage resources in workload namespaces. This is added by the **`gitops-instance`** chart (`templates/argocd-cluster-admin.yaml`). A restart of the application-controller StatefulSet may be required for the new binding to take effect (handled automatically on first install).

## Makefile reference

| Target | Role |
|--------|------|
| `phase1-gitops` | Seed GitOps + repo secret |
| `phase2-applicationset` | Install ApplicationSet |
| `gitops-full-bootstrap` | Phase 1 + 2 |
| `wait-openshift-gitops-csv` | Retry until GitOps CSV succeeds |
| `wait-argocd-ready` | Retry until ArgoCD CR is ready |
| `argocd-post-sync-waits` | Retry until key Applications are Healthy |
| `install-gitops-instance-repos` | Only repo Secret (+ chart metadata) |
| `teardown-bootstrap` | Uninstall ApplicationSet + Helm releases |

Run `make help` for the full list including legacy direct-install targets.

## Repository layout (high level)

```
bootstrap/
├── charts/
│   ├── operators/          # OLM charts (also synced by Argo from phase 2)
│   ├── instances/
│   ├── config/
│   └── gitops/
│       ├── platform-applicationset/   # ApplicationSet (Helm)
│       └── argocd-init-job/          # Post-sync Job chart
├── Makefile
├── .env.example
├── AGENTS.md
├── CLAUDE.md
└── .cursor/rules/
```

## Policy

- **Portable cluster access**: use `make` targets (login, phases, waits, teardown).
- **Pipelines** for cluster builds; **ImageStreams** for images; **podman** locally.
- **Parent folder** (e.g. multi-repo root) — do not add project files there; work in `bootstrap/` and `architecture/`.

Architecture specs and ADRs live in the **`architecture`** repository (`docs/`, `decisions/`, `specs/`).
