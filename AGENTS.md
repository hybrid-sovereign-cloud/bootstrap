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

## Known operational fixes

### OLM subscription ResolutionFailed (all operators)

**Symptom**: Operator ArgoCD apps show `Degraded` health; `oc get subscription -n <ns>` shows `ResolutionFailed=True` with message "clusterserviceversion ... exists and is not referenced by a subscription".

**Cause**: A CSV exists in the cluster but is not linked to its subscription (typically after an operator upgrade or subscription recreation without an InstallPlan).

**Fix procedure** (repeat for each affected namespace):
```bash
# 1. Create a stub InstallPlan for the existing CSV
oc create -f - -n <NAMESPACE> <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: InstallPlan
metadata:
  name: adopt-<SUBSCRIPTION_NAME>
spec:
  approval: Automatic
  approved: true
  clusterServiceVersionNames: ["<CSV_NAME>"]
EOF

# 2. Patch the subscription status to reference the CSV and InstallPlan
oc patch subscription.operators.coreos.com <SUBSCRIPTION_NAME> -n <NAMESPACE> \
  --type=merge --subresource=status -p '{
  "status": {"currentCSV": "<CSV_NAME>", "installedCSV": "<CSV_NAME>",
    "installPlanRef": {"apiVersion": "operators.coreos.com/v1alpha1",
      "kind": "InstallPlan", "name": "adopt-<SUBSCRIPTION_NAME>",
      "namespace": "<NAMESPACE>"}, "state": "AtLatestKnown"}}'

# 3. After ~30s, delete the stub InstallPlan (prevents InstallPlanPending)
oc delete installplan adopt-<SUBSCRIPTION_NAME> -n <NAMESPACE>
```

### NooBaa stuck in Configuring / OBC not Binding

**Cause**: ODF OperatorScaler requires `odf-dependencies` CSV to be present before scaling up the `noobaa-operator` deployment. If the MCG subscription has `ResolutionFailed`, the `noobaa-operator` stays at 0 replicas.

**Fix**:
1. Fix OLM subscriptions as above (apply to `openshift-storage` namespace for `odf-operator`)  
2. Restart ODF operator controller: `oc rollout restart deployment/odf-operator-controller-manager -n openshift-storage`
3. NooBaa operator scales up and reconciles NooBaa CR → BackingStore → BucketClass → OBC Bound

### MCH (RHACM) stuck Uninstalling

**Cause**: `ManagedClusterAddOn hypershift-addon` finalizer blocking MCH deletion.

**Fix**:
```bash
oc patch managedclusteraddon hypershift-addon -n local-cluster \
  --type=merge -p '{"metadata":{"finalizers":[]}}'
```

## AI policy

See [AI-POLICY.md](AI-POLICY.md) for the full governance policy applied to all AI-generated changes.

## References

- `bootstrap/README.md` — full installation guide  
- `architecture/docs/gitops-bootstrap.md` — GitOps workflow  
- `architecture/decisions/` — Architecture Decision Records  
- `bootstrap/AI-POLICY.md` — AI agent governance policy  
