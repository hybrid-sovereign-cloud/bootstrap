# ArgoCD Applications Reference

This document describes every ArgoCD Application deployed by the Sovereign Hybrid Cloud bootstrap process, its purpose, and the OCI Helm chart it uses.

All applications use OCI Helm charts hosted at `oci://quay.io/sovereignhybrid/<chart-name>`.

---

## Table of Contents

1. [Operators](#operators)
2. [Operator Instances](#operator-instances)
3. [Configuration Jobs](#configuration-jobs)
4. [Custom Operators](#custom-operators)
5. [Security & Compliance](#security--compliance)
6. [Observability & Management](#observability--management)

---

## Operators

### `gitops-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/gitops-operator`
- **Namespace**: `openshift-operators`
- **Purpose**: Installs the OpenShift GitOps operator (ArgoCD). This is the only application deployed via `make install-gitops-operator` using a direct OCI Helm chart without ArgoCD (bootstraps ArgoCD itself).
- **Make target**: `install-gitops-operator` / `uninstall-gitops-operator`

### `aap-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/aap-operator`
- **Namespace**: `ansible-automation-platform`
- **Purpose**: Installs the Ansible Automation Platform (AAP) operator, which manages the lifecycle of the AAP controller, EDA, and hub components.
- **Make target**: `install-aap-operator` / `uninstall-aap-operator`

### `eso-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/external-secrets-operator`
- **Namespace**: `external-secrets-operator`
- **Purpose**: Installs the External Secrets Operator (ESO), which synchronizes secrets from external secret stores (Vault) into Kubernetes Secrets.
- **Make target**: `install-eso-operator` / `uninstall-eso-operator`

### `rhbk-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/rhbk-operator`
- **Namespace**: `rhbk`
- **Purpose**: Installs the Red Hat Build of Keycloak (RHBK) operator for identity and access management.
- **Make target**: `install-rhbk-operator` / `uninstall-rhbk-operator`

### `quay-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/quay-operator`
- **Namespace**: `quay-enterprise`
- **Purpose**: Installs the Quay registry operator that manages the Red Hat Quay container registry lifecycle.
- **Make target**: `install-quay-operator` / `uninstall-quay-operator`

### `openshift-pipelines-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/openshift-pipelines-operator`
- **Namespace**: `openshift-operators`
- **Purpose**: Installs the OpenShift Pipelines (Tekton) operator for CI/CD pipeline execution used by custom operator builds.
- **Make target**: `install-openshift-pipelines-operator` / `uninstall-openshift-pipelines-operator`

### `odf-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/odf-operator`
- **Namespace**: `openshift-storage`
- **Purpose**: Installs the OpenShift Data Foundation (ODF) operator for persistent storage management, required by Quay (NooBaa object storage backend).
- **Make target**: `install-odf-operator` / `uninstall-odf-operator`

### `rhacm-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacm-operator`
- **Namespace**: `open-cluster-management`
- **Purpose**: Installs Red Hat Advanced Cluster Management (RHACM) operator for multi-cluster governance and policy management.
- **Make target**: `install-rhacm-operator` / `uninstall-rhacm-operator`

### `rhacs-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacs-operator`
- **Namespace**: `stackrox`
- **Purpose**: Installs Red Hat Advanced Cluster Security (RHACS) operator for runtime security and vulnerability management.
- **Make target**: `install-rhacs-operator` / `uninstall-rhacs-operator`

---

## Operator Instances

### `aap-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/aap-instance`
- **Namespace**: `ansible-automation-platform`
- **Purpose**: Deploys the AAP instance with the controller, Event-Driven Ansible (EDA), and hub components. Credentials are sourced from Vault via ExternalSecrets.
- **Make target**: `install-aap-instance` / `uninstall-aap-instance`

### `rhbk-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/rhbk-instance`
- **Namespace**: `rhbk`
- **Purpose**: Deploys the Keycloak (RHBK) instance used for SSO/OIDC authentication across all platform services (Quay, Vault, OpenShift).
- **Make target**: `install-rhbk-instance` / `uninstall-rhbk-instance`

### `quay-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/quay-instance` (v0.1.2)
- **Namespace**: `quay`
- **Purpose**: Deploys the Quay container registry using NooBaa as the object storage backend. Resource requests are tuned for constrained clusters (1Gi quay app, 512Mi database).
- **Make target**: `install-quay-instance` / `uninstall-quay-instance`
- **Dependencies**: `odf-noobaa` must be healthy and OBC must be Bound before Quay becomes available.

### `odf-noobaa`
- **Chart**: `oci://quay.io/sovereignhybrid/odf-noobaa` (v0.1.1)
- **Namespace**: `openshift-storage`
- **Purpose**: Deploys a NooBaa instance using the `standard-csi` storage class (OpenStack Cinder) as the database backend. Provides S3-compatible object storage for Quay.
- **Make target**: `install-odf-noobaa` / `uninstall-odf-noobaa`

### `vault-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/vault-instance`
- **Namespace**: `vault`
- **Purpose**: Deploys HashiCorp Vault as the platform secret management backend. All platform secrets are stored and retrieved from Vault.
- **Make target**: `install-vault-instance` / `uninstall-vault-instance`

### `gitea-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/gitea-instance` (v0.1.2)
- **Namespace**: `gitea`
- **Purpose**: Deploys a Gitea Git server for internal source code hosting. Admin credentials are stored in Vault.
- **Make target**: `install-gitea-instance` / `uninstall-gitea-instance`
- **Note**: `selfHeal: false` is set to prevent rollout loops caused by operator-managed Deployment drift.

### `gitops-instance` (phase1-gitops)
- **Chart**: `oci://quay.io/sovereignhybrid/gitops-instance`
- **Namespace**: `openshift-gitops`
- **Purpose**: Configures the ArgoCD instance with the correct project, RBAC, and repository credentials. This is the seed application that enables GitOps management of all other applications.
- **Make target**: `install-gitops-instance` / `uninstall-gitops-instance`

### `rhacm-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacm-instance`
- **Namespace**: `open-cluster-management`
- **Purpose**: Deploys the MultiClusterHub resource to activate RHACM. Set to Basic availability to reduce memory footprint on constrained clusters.
- **Make target**: `install-rhacm-instance` / `uninstall-rhacm-instance`

### `rhacs-instance`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacs-instance`
- **Namespace**: `stackrox`
- **Purpose**: Deploys the Central (RHACS control plane) and SecuredCluster (sensor, collector, admission-control) resources.
- **Make target**: `install-rhacs-instance` / `uninstall-rhacs-instance`

### `sovereign-cloud`
- **Chart**: `oci://quay.io/sovereignhybrid/sovereign-cloud` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Creates the `sovereign-cloud` namespace and base RBAC required for all custom operators and pipeline builds.
- **Make target**: `install-sovereign-cloud` / `uninstall-sovereign-cloud`

### `pipelines-bootstrap`
- **Chart**: `oci://quay.io/sovereignhybrid/pipelines-bootstrap`
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the OpenShift Pipelines configuration: ImageStream, PersistentVolumeClaim for workspace, and the Tekton feature flags configmap patch.
- **Make target**: `install-pipelines-bootstrap` / `uninstall-pipelines-bootstrap`

---

## Configuration Jobs

All configuration jobs use PostSync ArgoCD hooks with `BeforeHookCreation,HookSucceeded` delete policy, ensuring they re-run on each sync and are cleaned up on success.

### `vault-init`
- **Chart**: `oci://quay.io/sovereignhybrid/vault-init`
- **Namespace**: `vault`
- **Purpose**: Initializes Vault after first deploy: unseals it, enables the KV v2 secret engine at `central/`, configures Kubernetes auth, and creates the ESO service account policy. Stores unseal keys and root token in the `vault-init-keys` Kubernetes Secret.
- **Make target**: `install-vault-init` / `uninstall-vault-init`
- **PostSync Hook**: Yes — runs once after Vault is deployed.

### `keycloak-config`
- **Chart**: `oci://quay.io/sovereignhybrid/keycloak-config` (v0.1.1)
- **Namespace**: `rhbk`
- **Purpose**: Configures Keycloak after deploy:
  1. Creates the `sovereign-tenants` realm
  2. Creates the `sovereign-admins` group
  3. Creates the `sovereign-tenants-client` OIDC client and stores credentials in Vault at `central/keycloak/sovereign-tenants-client`
  4. Creates the `initial-sovereign-admin` user and stores credentials in Vault
  5. Creates per-service OIDC clients: `quay-oidc`, `openshift-oidc`, `vault-oidc` and stores each in Vault at `central/quay/oidc`, `central/openshift/oidc`, `central/vault/oidc`
- **Make target**: `install-keycloak-config` / `uninstall-keycloak-config`
- **PostSync Hook**: Yes — runs after RHBK instance is deployed.

### `dynamic-plugins-config`
- **Chart**: `oci://quay.io/sovereignhybrid/dynamic-plugins-config` (v0.1.1)
- **Namespace**: `openshift-console`
- **Purpose**: Enables dynamic console plugins on the OpenShift console by patching the `consoles.operator.openshift.io cluster` resource. Currently enables: `sovereign-cloud-plugin`, `odf-console`, `pipelines-console-plugin`, `gitops-plugin`, `acm`, `mce`, `advanced-cluster-security`, `monitoring-plugin`, `networking-console-plugin`.
- **Make target**: `install-dynamic-plugins-config` / `uninstall-dynamic-plugins-config`

### `rhacm-config`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacm-config`
- **Namespace**: `open-cluster-management`
- **Purpose**: Configures RHACM policies and managed cluster sets for the sovereign cloud governance model.
- **Make target**: `install-rhacm-config` / `uninstall-rhacm-config`

### `rhacs-config`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacs-config`
- **Namespace**: `stackrox`
- **Purpose**: Configures RHACS with sovereign cloud security policies, including network policies and compliance profiles.
- **Make target**: `install-rhacs-config` / `uninstall-rhacs-config`

### `service-oidc-config`
- **Chart**: `oci://quay.io/sovereignhybrid/service-oidc-config`
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys RBAC resources (ServiceAccount, Roles, RoleBindings, ClusterRole) that allow the platform's service-to-service OIDC token exchange. Grants the `service-oidc-sa` ServiceAccount read access to OIDC secrets in `sovereign-cloud`, `quay`, and `vault` namespaces.
- **Make target**: `install-service-oidc-config` / `uninstall-service-oidc-config`

---

## Custom Operators

### `custom-operators-git-creds`
- **Chart**: `oci://quay.io/sovereignhybrid/custom-operators-git-creds`
- **Namespace**: `sovereign-cloud`
- **Purpose**: Creates the Git credentials Secret (from Vault `central/github` ExternalSecret) used by the Tekton pipelines to clone private GitHub repositories during operator builds.
- **Make target**: `install-custom-operators-git-creds` / `uninstall-custom-operators-git-creds`

### `custom-operators-pipelines`
- **Chart**: `oci://quay.io/sovereignhybrid/custom-operators-pipelines` (v0.1.2)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the Tekton Pipeline definitions for each custom operator build. Each pipeline: clones the operator's Git repository, builds the container image using Buildah, and pushes to the OpenShift internal image registry. The `sovereign-cloud-console` pipeline uses a custom `DOCKERFILE` path (`console-plugin/Containerfile`).
- **Make target**: `install-custom-operators-pipelines` / `uninstall-custom-operators-pipelines`
- **Build targets**: `trigger-build-<operator>` for each operator (assignment, cloudaws, cloudoso, platformopenshift, projects, team, plugin-rbac, sovereign-cloud-console)

### `assignment-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/assignment-operator` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the Assignment custom operator. Manages `Assignment` CRs that assign cloud resources to tenants. Includes a metrics sidecar (port 8081) and ServiceMonitor for Prometheus scraping.
- **Make target**: `install-assignment-operator` / `uninstall-assignment-operator`

### `cloudaws-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/cloudaws-operator` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the CloudAWS custom operator. Manages `CloudAWS` CRs representing AWS cloud account configurations for tenants.
- **Make target**: `install-cloudaws-operator` / `uninstall-cloudaws-operator`

### `cloudoso-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/cloudoso-operator` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the CloudOSO custom operator. Manages `CloudOSO` CRs representing OpenStack cloud configurations for tenants.
- **Make target**: `install-cloudoso-operator` / `uninstall-cloudoso-operator`

### `entity-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/entity-operator`
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the Entity (sovereign_tenancy) custom operator. Manages `SovereignTenancy` CRs, the top-level tenant entity in the sovereign cloud hierarchy. Serves as the reference implementation for metrics and event emission.
- **Make target**: `install-entity-operator` / `uninstall-entity-operator`

### `platformopenshift-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/platformopenshift-operator` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the PlatformOpenshift custom operator. Manages `PlatformOpenshift` CRs representing OpenShift cluster configurations for tenant platforms.
- **Make target**: `install-platformopenshift-operator` / `uninstall-platformopenshift-operator`

### `projects-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/projects-operator` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the Projects custom operator. Manages `Projects` CRs that group resources into logical projects within a tenant.
- **Make target**: `install-projects-operator` / `uninstall-projects-operator`

### `team-operator`
- **Chart**: `oci://quay.io/sovereignhybrid/team-operator` (v0.1.1)
- **Namespace**: `sovereign-cloud`
- **Purpose**: Deploys the Team custom operator. Manages `Team` CRs representing organizational teams with associated RBAC within the sovereign cloud.
- **Make target**: `install-team-operator` / `uninstall-team-operator`

### `plugin-rbac`
- **Chart**: `oci://quay.io/sovereignhybrid/rbac-plugin-operator` (v0.2.1)
- **Namespace**: `sovereign-cloud-plugins`
- **Purpose**: Deploys the RBAC Plugin operator. Manages the `RBACConfig` CR that configures role-based access control for the sovereign-cloud-plugin console extension.
- **Make target**: `install-plugin-rbac` / `uninstall-plugin-rbac`

### `sovereign-cloud-console`
- **Chart**: N/A (built via Tekton, deployed as image to internal registry)
- **Namespace**: `sovereign-cloud`
- **Purpose**: The OpenShift console dynamic plugin for the Sovereign Cloud platform. Provides custom UI pages for managing sovereign cloud resources. Built from `console-plugin/Containerfile` in the sovereign-cloud-console repository.
- **Build target**: `trigger-build-sovereign-cloud-console` / `wait-build-sovereign-cloud-console`

---

## Security & Compliance

### `external-secrets-config`
- **Chart**: `oci://quay.io/sovereignhybrid/external-secrets-config`
- **Namespace**: `sovereign-cloud` (with cross-namespace resources)
- **Purpose**: Configures the External Secrets Operator to sync the following secrets from Vault into Kubernetes:
  | ExternalSecret | Vault Path | Target Namespace |
  |---|---|---|
  | `github-basic-auth` | `central/github` | `sovereign-cloud` |
  | `keycloak-auth-config` | `central/keycloak/auth-config` | `sovereign-cloud` |
  | `keycloak-client-secret` | `central/keycloak/sovereign-tenants-client` | `sovereign-cloud` |
  | `gitea-admin-secret` | `central/gitea/admin` | `gitea` |
  | `openshift-oidc-secret` | `central/openshift/oidc` | `openshift-config` |
  | `quay-oidc-secret` | `central/quay/oidc` | `quay` |
  | `vault-oidc-secret` | `central/vault/oidc` | `vault` |
- **Make target**: `install-external-secrets-config` / `uninstall-external-secrets-config`
- **Dependency**: Requires `keycloak-config` PostSync job to have completed successfully.

---

## Observability & Management

### `rhacm-config`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacm-config`
- **Namespace**: `open-cluster-management`
- **Purpose**: Applies RHACM governance policies and managed cluster configurations for the sovereign hybrid cloud model.

### `rhacs-config`
- **Chart**: `oci://quay.io/sovereignhybrid/rhacs-config`
- **Namespace**: `stackrox`
- **Purpose**: Applies RHACS security policies including network segmentation policies and CIS compliance profiles for the sovereign cloud namespaces.

---

## Deployment Order

The applications are deployed in wave order (ArgoCD sync-wave annotation). Lower waves deploy first:

| Wave | Application |
|------|-------------|
| 10 | `gitops-operator` |
| 20 | `openshift-pipelines-operator`, `eso-operator`, `rhbk-operator`, `quay-operator`, `odf-operator`, `rhacm-operator`, `rhacs-operator`, `aap-operator` |
| 30 | `vault-instance` |
| 40 | `vault-init` |
| 50 | `eso-operator` configuration |
| 60 | `external-secrets-config`, `sovereign-cloud`, `pipelines-bootstrap` |
| 70 | `gitea-instance`, `rhbk-instance`, `odf-noobaa` |
| 80 | `quay-instance`, `rhacm-instance`, `rhacs-instance`, `aap-instance` |
| 90 | `custom-operators-git-creds`, `custom-operators-pipelines` |
| 100 | `keycloak-config`, `rhacm-config`, `rhacs-config` |
| 110 | `dynamic-plugins-config`, `service-oidc-config` |
| 120 | `assignment-operator`, `cloudaws-operator`, `cloudoso-operator`, `entity-operator`, `platformopenshift-operator`, `projects-operator`, `team-operator`, `plugin-rbac` |
| 130 | `sovereign-cloud-console` |

---

## Required Environment Variables

The following environment variables must be set before running any `make` commands:

```bash
# OpenShift cluster credentials
export OCP_SERVER="https://api.<cluster>.<domain>:6443"
export OCP_USERNAME="kubeadmin"
export OCP_PASSWORD="<password>"

# OCI Registry (Quay.io)
export OCI_REGISTRY="quay.io/sovereignhybrid"
export OCI_REGISTRY_TOKEN="<quay-robot-token>"

# GitHub token for pipeline builds
export GITHUB_TOKEN="<github-pat>"
```

See the [bootstrap README](../README.md) for the full prerequisite setup.
