# Security Assessment — Tenancy Operators

## Applicability

The five tenancy controllers (**Team**, **Assignment**, **Project**, **PlatformOpenshift**, **CloudOSO**) augment the Sovereign Bootstrap **services** cluster at **Argo CD sync wave 38** — see `bootstrap/helm/central/values.yaml` and [Tenancy Ansible operators](../docs/technical/20-tenancy-operators.md). This complements the centralized findings in the repository-level [`architecture/hardeningcheck/security-assessment.md`](../../../architecture/hardeningcheck/security-assessment.md).

## RBAC analysis

Each operator chart installs a **`ClusterRole`** paired with **`ClusterRoleBinding`** (or namespace-scoped alternatives where applicable) constrained to verbs required for playbook tasks—typically **`get`/`list`/`watch`** on namespaces and owned APIs, **`patch`/`update`** on status sub-resources, leases for leader election, and **`create`/`patch`** on events — **avoiding granting `*` on `*`**.

**Recommendation:** Regression-test RBAC manifests whenever Ansible tasks touch new Kubernetes groups; prefer **explicit resourceNames** once stable.

## Pod security posture

Workload expectation (controller-manager **`Deployment`**):

| Control | Expected value |
|---------|----------------|
| **`runAsNonRoot`** | `true` |
| **`allowPrivilegeEscalation`** | `false` |
| **`capabilities.drop`** | `["ALL"]` |
| **`seccompProfile`** | `type: RuntimeDefault` |

Charts should reconcile with **Restricted** PSA policy on **`sovereign-cloud`**.

## Image provenance

- Base: **`quay.io/operator-framework/ansible-operator:v1.42.2`**
- Application bundle adds **collections + playbooks**, built into the operator image mirrored at org Quay (**`hybrid-sovereign/*`**). Pin by digest downstream for gold images.

## Network exposure

**Metrics:**

- Listening on **IPv4 `:8443`** inside pods.
- **`Service` ClusterIP only — no Routes** exposing metrics outside the mesh.

**Recommendation:** Optionally add egress **`NetworkPolicy`** so operators only speak to **`kubernetes.default.svc`** and required DNS resolver(s); keep scrape ingress narrowly sourced from Prometheus/UWM namespaces (`network.openshift.io/policy-group` / monitoring labels depending on topology).

## Deviation accepted — single shared namespace

**Finding:** Operators all land in **`sovereign-cloud`** rather than segregated **`team-operator-system`**-style namespaces.

**Impact:** Increased blast radius versus hard multi-tenant operator isolation.

**Mitigation / posture:** Accepted **simplicity trade-off for prototype / Day-1 installs** alongside strict pod security boundaries and separate **service accounts**.

## Next steps checklist

| Action | Priority |
|--------|---------|
| Adopt egress **NetworkPolicies** for operator Deployments | Medium |
| Document controller-specific RBAC deltas in Helm `values.yaml` comments | Low |
| Move to pinned image digests via release automation | Medium |
