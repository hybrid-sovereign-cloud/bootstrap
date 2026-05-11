# Prometheus Metrics — Hybrid Sovereign Operators

## Summary

**Ansible SDK operators** in the **`hybridsovereign.redhat`** API surface expose Prometheus-style metrics **over HTTPS on port `8443`**. Charts render:

1. **`Service`** — exposes **`https-metrics`** on **8443** to controller-manager pods only.
2. **`ServiceMonitor`** — User Workload / platform Prometheus scrapes via in-cluster bearer token (when `.Values.metrics.serviceMonitor.enabled` is true).
3. **`PrometheusRule`** — per-operator alerting.

There are **no OpenShift Routes** for metrics scrape paths; scraping stays on cluster Service networking.

## Alert rules

Each tenancy operator chart emits two Prometheus rules naming the **`controller`**/`job`:

| Tenant operator | Reconcile-errors alert | Down alert |
|-----------------|------------------------|------------|
| Team | `TeamReconcileErrors` | `TeamOperatorDown` |
| Assignment | `AssignmentReconcileErrors` | `AssignmentOperatorDown` |
| Project | `ProjectReconcileErrors` | `ProjectOperatorDown` |
| PlatformOpenshift | `PlatformOpenshiftReconcileErrors` | `PlatformOpenshiftOperatorDown` |
| CloudOSO | `CloudOSOReconcileErrors` | `CloudOSOOperatorDown` |

The **entity operator** mirrors the pattern (`Entity*` alerts, `job="entity-operator-metrics"`).

## Metrics Kubernetes `Service` names

These services are deployed in **`sovereign-cloud`** alongside each operator Helm release.

| Operator | Metrics Service name (`metadata.name`) |
|----------|----------------------------------------|
| Entity | `entity-operator-metrics` |
| Team | `team-operator-metrics` |
| Assignment | `assignment-operator-metrics` |
| Project | `project-operator-metrics` |
| PlatformOpenshift | `platformopenshift-operator-metrics` |
| CloudOSO | `cloudoso-operator-metrics` |

Separate **plugin operators** (`plugin-*` charts under the platform repos) reuse the **8443** pattern with their own `Service`/`ServiceMonitor`/`PrometheusRule` triples—see respective chart docs.

## Related Documentation

- [Tenancy Ansible operators](20-tenancy-operators.md)
