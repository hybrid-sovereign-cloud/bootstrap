# AI Policy — Hybrid Sovereign Cloud Bootstrap

> **Version:** 1.0  
> **Status:** Active — applied to all AI agent sessions (Cursor, Claude, GitHub Copilot, etc.)  
> **Authority:** This document takes precedence over model defaults.

---

## 1. Purpose

This policy governs how AI coding assistants interact with the `bootstrap/` and `architecture/` repositories for the Hybrid Sovereign Cloud platform. It ensures:

- **Reproducibility** — Any change an AI makes can be replayed on a fresh cluster via `make` targets.
- **Security** — Secrets never enter source control; all sensitive data flows through Vault → ESO.
- **Observability** — All AI-authored changes are committed with clear messages and linked to ADRs.
- **Governance** — No AI agent has unbounded write access to cluster or infrastructure state.

---

## 2. Scope

| In scope | Out of scope |
|----------|-------------|
| `bootstrap/` charts, Makefile, CI | Workspace root (`/`) — no writes |
| `architecture/` specs, decisions, docs | External systems (Quay.io, GitHub secrets) |
| OpenShift cluster via `oc` wrapped in `make` | Direct API calls to cloud providers |

---

## 3. Mandatory behaviours

### 3.1 Read before write

The agent MUST read any file before editing it. No blind overwrites.

### 3.2 Validate after every chart change

```bash
make validate-helm   # runs helm template on every chart; must exit 0
```

### 3.3 Use Makefile for all cluster interaction

Every `oc` command an agent executes must be wrapped in a `make` target or a Helm PostSync Job. Bare `oc apply` / `oc create` in conversation history or scripts are **forbidden**.

### 3.4 GitOps-only cluster installs

After Phase 1 bootstrap, all cluster state changes MUST flow through:

```
Git commit → Argo CD sync → Helm chart application
```

Not through direct `helm upgrade` on the production cluster (except `make phase2-applicationset` which installs the ApplicationSet itself).

### 3.5 Secret handling

- **Never** commit plaintext secrets, tokens, or passwords.
- Vault is the single source of truth for secrets: `central/<service>/<key>`.
- Kubernetes Secrets are created exclusively by ESO `ExternalSecret` resources.
- Init tokens (Vault root token, ACS admin password) are stored in cluster Secrets with RBAC-scoped read access and removed after bootstrap.

### 3.6 Build and image pipeline

- Container images MUST be built via OpenShift Pipelines (Tekton).
- Images MUST be pushed to OpenShift ImageStreams, not external registries directly.
- Pipeline definitions live in `bootstrap/charts/instances/pipelines-bootstrap/`.

### 3.7 Documentation

After any meaningful change, the agent MUST update:

1. Relevant `README.md` (chart, bootstrap root, or architecture)
2. `Makefile` help text (`## description`) for any new make target
3. An Architecture Decision Record in `architecture/decisions/` (new ADR or amendment)

### 3.8 Commit discipline

- Commit messages follow: `<type>: <short description>` (feat/fix/docs/refactor/chore)
- Body explains *why*, not *what*
- Every push keeps the `main` branch deployable

---

## 4. Prohibited actions

| Action | Reason |
|--------|--------|
| Write files to workspace root | Violates repo boundary policy |
| `oc apply -f -` with inline YAML in shell | Bypasses Helm/GitOps governance |
| Hardcode secrets in any chart or config file | Security violation |
| Force-push to `main` | Destroys history |
| Skip `make validate-helm` after chart changes | Risks broken deployments |
| Install operators/instances outside ApplicationSet | Breaks idempotency |
| Use external image registries for builds | Violates image pipeline policy |

---

## 5. Permitted exceptions (documented)

| Exception | Condition | Documentation required |
|-----------|-----------|----------------------|
| `oc rollout restart` | After config-bundle update to restart pods | ADR note |
| `oc patch ... --type=json` | Remove finalizers during teardown | Teardown runbook |
| `oc exec` into Vault pod | Bootstrap unseal only; replaced by PostSync job | ADR-0005 |
| `oc get` for read-only debugging | Any time | None required |

---

## 6. AI agent responsibilities by phase

### Phase 1 — Initial bootstrap

- Run `make phase1-gitops` only
- Validate GitOps operator and Argo CD are running before proceeding

### Phase 2 — ApplicationSet deployment

- Run `make phase2-applicationset` with correct `APPS_DOMAIN` and `GITHUB_URL`
- Confirm all Applications reach `Synced + Healthy` before declaring done

### Development loop

```
1. Edit chart(s) in bootstrap/
2. make validate-helm
3. git add && git commit && git push
4. Argo CD auto-syncs (or: oc annotate application <app> argocd.argoproj.io/refresh=hard)
5. Check application health: make verify-argocd-app-health
6. If broken: debug with oc logs / oc describe, fix in chart, go to step 1
```

### Teardown

- Run `make teardown-bootstrap` then `make delete-bootstrap-namespaces`
- For stubborn resources: remove finalizers with `oc patch` (documented exception)
- Verify clean: `oc get all -n <ns>` for each bootstrap namespace

---

## 7. Compliance

AI agents that violate this policy should be corrected by the user immediately. This document is version-controlled and auditable. Updates require a commit to `main` with an explicit change description.

---

*Last updated: $(date -u +%Y-%m-%d) by AI policy enforcement system.*
