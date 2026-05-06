# Security hardening — bootstrap (Helm charts + Makefile)

GitOps-oriented bootstrap: Argo CD instances, identity, secrets (Vault / ESO), operators, and supporting jobs.

## Identified risks

| Severity | Topic | Location | Notes |
|----------|--------|----------|--------|
| **CRITICAL** | Default Gitea admin password committed in chart values | `charts/instances/gitea-instance/values.yaml` (`gitea.gitea.admin.password`) | Anyone with repo access knows the default `SovereignCloud2026!`—**override via Vault/ESO before any shared environment** and rotate if this was ever deployed. |
| **HIGH** | Argo CD ClusterRoleBindings grant **cluster-admin** | `charts/instances/gitops-instance/templates/argocd-cluster-admin.yaml` | Documented as required for ROSA/managed OpenShift; still maximum privilege—consider dedicated scoped ClusterRoles if platform allows. |
| **HIGH** | `argocd-init-job` binds release-specific SA to cluster-admin | `charts/gitops/argocd-init-job/templates/rbac.yaml` | Post-sync job runs with full cluster control; ensure hook chart is trusted and immutable. |
| **HIGH** | GitHub / OCI tokens in Helm values at install time | `charts/instances/gitops-instance/templates/repository-secret.yaml`, `custom-operators-git-creds`, etc. | Values often sourced from env (`GITHUB_TOKEN`)—ensure CI logs never echo them. |
| **MEDIUM** | Container images using `:latest` tags | e.g. `charts/instances/custom-operators-pipelines/values.yaml` (`buildahImage`), `charts/config/dynamic-plugins-config/templates/job.yaml` (`cli:latest`), `charts/gitops/argocd-init-job/values.yaml` (`ubi9/ubi:latest`), `charts/instances/rhacm-instance/values.yaml`, `charts/instances/rhacs-instance/values.yaml` | Non-reproducible deploys and surprise upgrades. |
| **MEDIUM** | Sparse default NetworkPolicies | e.g. `charts/config/external-secrets-config/templates/networkpolicy.yaml` (ESO→Vault) | Many app namespaces lack deny-by-default policies—add per-namespace policies in charts. |
| **LOW** | `.env` for local creds gitignored | `.gitignore` | Confirms pattern; verify no secrets committed under other paths. |

## Helm / platform checklist

- [ ] **Remove or externalize** default Gitea admin password; sync from Vault before sync wave reaches Gitea.
- [ ] Replace Argo CD `cluster-admin` bindings with narrow aggregates where technically feasible; document exceptions.
- [ ] Pin every runtime image to digest or explicit semver (no `:latest` in prod values).
- [ ] Add default **deny-all** NetworkPolicy templates for sensitive namespaces (Vault, GitOps, identity) with explicit egress allowlists.
- [ ] Ensure all workloads set `securityContext` (`runAsNonRoot`, `readOnlyRootFilesystem` where possible, dropped caps).
- [ ] Enable Pod Security Admission / SCC alignment on OpenShift for chart workloads.
- [ ] Verify ExternalSecret resources reference Vault paths—not inline secret literals in committed values.
- [ ] Run `helm template` + policy checks (kubeconform, kube-linter, kyverno) in CI.

## Repository hygiene

- [x] `.env` listed in `.gitignore` for local cluster credentials.
- [ ] Periodic audit for accidental secret commits (`git-secrets`, `gitleaks`).

This repo has **no** `config/samples/` tree; commits here only add `hardening-checks/HARDENING.md`.
