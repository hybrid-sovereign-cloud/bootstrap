# AGENTS.md — Hybrid Sovereign Cloud Bootstrap

Applies to: Cursor, Claude, and all AI agents working in this repository.

## Hard rules (always enforced)

| Rule | Detail |
|------|--------|
| **Repo boundary** | Only modify `bootstrap/` and `architecture/`. Never write to the workspace root (`/`). |
| **Helm-only installs** | All Kubernetes resources are installed via Helm charts. Direct `oc apply` or `oc create` are forbidden except in validated PostSync Job scripts. |
| **Make for cluster interaction** | Every OpenShift CLI interaction must have a `make` target so the setup is reproducible on any cluster. |
| **Validate before done** | Run `make validate-helm` before declaring any chart work complete. |
| **GitOps first** | All cluster state after Phase 1 is driven by the Argo CD ApplicationSet (`platform-gitops`). No manual Helm installs into production cluster after Phase 2. |
| **Secrets via Vault + ESO** | Never hardcode secrets. Store in HashiCorp Vault; pull with External Secrets Operator ExternalSecrets. |
| **Builds via OpenShift Pipelines** | Use Tekton for all container builds; push results to Quay (`quay.signal9.gg/hybrid-sovereign`). No internal ImageStreams. |
| **Private Quay only** | ALL Quay repos in `hybrid-sovereign` MUST stay **private**. After any push: `make oci-make-private && make oci-grant-robot-access`. Never make a repo public. |
| **Robot credentials everywhere** | After adding a namespace run `make oci-bootstrap-pull-secrets`. Link secret to operator SAs: `oc secrets link <sa> quay-robot-pull-secret --for=pull`. |
| **ArgoCD OCI auth** | Each OCI chart repo needs an individual `argocd.argoproj.io/secret-type: repository` Secret. Add repos to `ociRegistry.repositories` in `gitops-instance/values.yaml` then `make install-gitops-instance`. |
| **Git freely** | `git add`, `commit`, `push` allowed at any time to keep history clean. |
| **Update docs** | Update the relevant README, Makefile help text, and an architecture ADR on every meaningful change. |
| **Iterate until fixed** | Deploy → test → fix loop; **`oc` read-only** (get/describe/logs); cluster **writes** via **`make`** targets; fix chart/Makefile, commit, re-sync. |
| **No root writes** | Never create files at the repo root. |

## GitOps bootstrap sequence

```
Phase 1  →  make phase1-gitops
             - Install OpenShift GitOps (cluster-scoped)
             - Configure Argo CD + Git repository secret (GITHUB_URL / GITHUB_TOKEN)

Phase 2  →  make phase2-applicationset
             - Helm install platform-applicationset
             - Argo CD ApplicationSet drives all subsequent installs (sync waves)
```

## Sync wave order

| Wave | Apps |
|------|------|
| 10–70 | Operators (AAP, ESO, ODF, Pipelines, Quay, RHBK, RHACM, RHACS) |
| 100–155 | Instances (sovereign-cloud, Vault, AAP, RHBK, Gitea, ODF-NooBaa, Pipelines, Quay, RHACM, RHACS) |
| 200–245 | Config jobs (vault-init, keycloak-config, external-secrets-config, service-oidc-config, rhacs-config, rhacm-config) |
| 250 | argocd-init-job (post-sync waits) |

## Operator install sequence

1. aap-operator  
2. external-secrets-operator  
3. odf-operator  
4. openshift-pipelines-operator  
5. quay-operator  
6. rhbk-operator  
7. rhacm-operator  
8. rhacs-operator  

All subscriptions set `installPlanApproval: Automatic`.

## PostSync hook pattern

Jobs that require runtime discovery (secrets, routes, init bundles) are annotated:

```yaml
argocd.argoproj.io/hook: PostSync
argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

This makes them re-run on every sync without immutable Job spec conflicts.

## Secret flow

```
Vault KV (central/) → ExternalSecret (ESO) → Kubernetes Secret → App
```

Vault is unsealed by the `vault-init` PostSync job. The root token is stored in `vault-init-keys` Secret and read by subsequent config jobs via RBAC-scoped Service Accounts.

## AI policy

See [AI-POLICY.md](AI-POLICY.md) for the full governance policy applied to all AI-generated changes.

## References

- `bootstrap/README.md` — full installation guide  
- `architecture/docs/gitops-bootstrap.md` — GitOps workflow  
- `architecture/decisions/` — Architecture Decision Records  
- `bootstrap/AI-POLICY.md` — AI agent governance policy  
