# CLAUDE.md — Agent Rules for Hybrid Sovereign Cloud Bootstrap

## Phase 1 Design Philosophy (ADR-0022)

- **Rapid initialisation**: `make phase1-gitops && make phase2-applicationset` = zero-to-platform on any cluster.
- **Makefile portability**: every OCP mutation is a `make` target; rerunnable by env vars only.
- **OCP Appliance end-goal**: pipeline produces a versioned appliance image for sovereign/air-gapped deployments.
- **Developer sandbox**: clone → set env → `make` = isolated dev cluster, no shared cluster needed.
- **OC read-only**: `oc`/`kubectl` for investigation only; mutations via `make` or ArgoCD.

## Repository layout

- Work only **`bootstrap/`** and **`architecture/`**; never add project files to a parent workspace root.
- Run **`make validate-helm`** after chart or Makefile changes.
- You may **`git commit` / `push`** as needed when work is coherent.

## Environment

- OpenShift: `OCP_SERVER`, `OCP_USERNAME`, `OCP_PASSWORD`
- GitOps: `GITHUB_URL` (HTTPS repo with this tree), `GITHUB_TOKEN`, `GITHUB_REVISION` (optional)

## Deployment model (GitOps-first)

1. **`make phase1-gitops`** — Cluster-scoped OpenShift GitOps operator; **`install-gitops-instance-repos`** creates **`platform-git-repository`** with `insecure: "true"` for Git TLS when needed.
2. **`make phase2-applicationset`** — Inst **`platform-applicationset`**; Argo CD owns all remaining charts with **prune** + **selfHeal** and **sync waves**.
3. **`argocd-init-job`** — PostSync Job (cluster-admin SA) clones repo and runs **`make argocd-post-sync-waits`** (extend via chart values).

**Helm** for all chart installs; avoid **`oc apply`** / **`oc create`** in Makefile except documented teardown / OLM exceptions.

**Portability**: cluster operations go through **`make`** (login, phases, waits, teardown).

## Operators

All bootstrap **`installPlanApproval: Automatic`** (including RHBK). Legacy `make approve-rhbk-installplan` only if a CSV is still Manual.

## Builds

- **OpenShift Pipelines** — `charts/operators/openshift-pipelines-operator` + `pipelines-bootstrap`.
- **ImageStreams** — `charts/instances/pipelines-bootstrap`.
- **Podman** for local builds.

## Testing

- **`make validate-helm`**
- **`make phase1-gitops`** then **`phase2-applicationset`** on a cluster; debug with **`oc get applications -n openshift-gitops`**, Argo logs, and Makefile wait targets.
- **Iterate:** fix failing wave, commit, re-sync; use **`make status`** / per-component **`make wait-*`** / **`make debug-*`** (read-only) before changing Helm.
- **Agents:** prefer **`make`** for any cluster mutation; use **`oc`/`kubectl` only for read-only investigation** (get, describe, logs).

## Documentation

- `bootstrap/README.md`, `architecture/docs/gitops-bootstrap.md`, **`architecture/decisions/`** for ADRs.

## Teardown

- **`make teardown-bootstrap`** (uninstalls ApplicationSet release and Helm-managed operators/instances).
