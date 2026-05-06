# Developer Guide: Hybrid Sovereign Cloud Platform

This guide explains how to develop, build, test, and deploy changes to any of the 8 custom operators in the Sovereign Cloud platform.

---

## Platform Overview

The platform consists of:

1. **Bootstrap operators** (managed by `platform-applicationset`): ArgoCD, Vault, ESO, RHBK, Quay, ODF, RHACM, RHACS, OpenShift Pipelines
2. **Custom domain operators** (managed by `custom-operators-appset`): plugin_rbac, sovereign_tenancy, CloudAWS, CloudOSO, PlatformOpenshift, Team, Projects, Assignment

All custom operators are **Ansible Operator SDK** projects. They are:
- Built via **OpenShift Pipelines (Tekton)** inside the cluster
- Deployed via **ArgoCD ApplicationSet** sourcing from each operator's own GitHub repo
- Images stored in **OpenShift ImageStreams** in the `sovereign-cloud` namespace

---

## Prerequisites

### Cluster Access
```bash
export OCP_SERVER=https://api.<cluster>:6443
export OCP_USERNAME=<user>
export OCP_PASSWORD=<password>
export GITHUB_URL=https://github.com/hybrid-sovereign-cloud/bootstrap.git
export GITHUB_TOKEN=<pat>
```

Or put them in `bootstrap/.env`:
```bash
OCP_SERVER=https://api.<cluster>:6443
OCP_USERNAME=<user>
OCP_PASSWORD=<password>
GITHUB_URL=https://github.com/hybrid-sovereign-cloud/bootstrap.git
GITHUB_TOKEN=<ghp_...>
```

### Tools Required
- `oc` (OpenShift CLI) 4.14+
- `helm` 3.12+
- `git`
- `make`

---

## Quick Start: Full Platform Rebuild

To deploy everything from scratch on a brand new OpenShift cluster:

```bash
cd bootstrap/
make rebuild-all
```

This single command:
1. Logs into OpenShift
2. Installs OpenShift GitOps operator (Phase 1)
3. Deploys the platform ApplicationSet (Phase 2, all bootstrap operators)
4. Deploys ArgoCD org credentials for the custom operator repos
5. Deploys OpenShift Pipelines definitions and ImageStreams for all 8 operators
6. Deploys the custom-operators ApplicationSet

Then trigger image builds:
```bash
make trigger-build-all
```

Wait for everything to be ready:
```bash
make wait-custom-operators
make status-custom-operators
```

---

## Individual Operator Development Workflow

### 1. Make a code change
Edit the Ansible role in your operator repo:
```bash
cd ../CloudAWS
# edit roles/cloudaws/tasks/main.yml
git add -A && git commit -m "feat: add AWS account creation" && git push
```

### 2. Build the new image in-cluster
```bash
cd bootstrap/
make trigger-build OPERATOR=cloudaws-operator
```

Monitor the build:
```bash
oc get pipelinerun -n sovereign-cloud | grep cloudaws
oc logs -n sovereign-cloud -f pipelinerun/cloudaws-operator-build-xxxxx --all-containers
```

### 3. Restart the operator deployment
After a successful build, the ImageStream is updated. Restart the operator:
```bash
oc rollout restart deployment/cloudaws-operator -n sovereign-cloud
oc rollout status deployment/cloudaws-operator -n sovereign-cloud
```

### 4. Verify reconciliation
```bash
oc logs -n sovereign-cloud deployment/cloudaws-operator -f
```

---

## Operator-Specific Developer READMEs

Each operator repo has a `DEVELOPER_README.md` with operator-specific instructions:

| Repo | README | Description |
|------|--------|-------------|
| `plugin_rbac` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/plugin_rbac/blob/main/DEVELOPER_README.md) | RbacConfig + Rbac → Keycloak groups |
| `sovereign_tenancy` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/sovereign_tenancy/blob/main/DEVELOPER_README.md) | Entity + Container (composition hub) |
| `CloudAWS` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/CloudAWS/blob/main/DEVELOPER_README.md) | AWS cloud resource operator |
| `CloudOSO` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/CloudOSO/blob/main/DEVELOPER_README.md) | OpenStack cloud resource operator |
| `PlatformOpenshift` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/PlatformOpenshift/blob/main/DEVELOPER_README.md) | OCP platform instance operator |
| `Team` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/Team/blob/main/DEVELOPER_README.md) | Team namespace + RBAC operator |
| `Projects` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/Projects/blob/main/DEVELOPER_README.md) | Project namespace operator |
| `Assignment` | [DEVELOPER_README.md](https://github.com/hybrid-sovereign-cloud/Assignment/blob/main/DEVELOPER_README.md) | App-to-Infra bridge operator |

---

## RBAC: Creating Entities and Assigning Access

### Step 1: Create a RbacConfig (one-time per cluster)
```bash
oc apply -f - <<EOF
apiVersion: hybridsovereign.redhat/v1alpha1
kind: RbacConfig
metadata:
  name: keycloak-base
  namespace: sovereign-cloud
spec:
  keycloak:
    secret: keycloak-auth-config
    base_path: "/"
    managed: true
EOF
```

### Step 2: Create an Entity
```bash
oc apply -f - <<EOF
apiVersion: hybridsovereign.redhat/v1alpha1
kind: Entity
metadata:
  name: acme
spec:
  residency: iaas
  adminGroup:
    - acme/admins
  developerGroup:
    - acme/developers
EOF
```

### Step 3: Create Rbac CRs for group validation
```bash
# After entity-acme namespace is created by entity-operator:
oc apply -f - <<EOF
apiVersion: hybridsovereign.redhat/v1alpha1
kind: Rbac
metadata:
  name: admins
  namespace: entity-acme
spec:
  rbacConfig: keycloak-base
EOF
```

### Step 4: Create cloud infrastructure via Container
```bash
oc apply -f - <<EOF
apiVersion: hybridsovereign.redhat/v1alpha1
kind: Container
metadata:
  name: aws-prod
  namespace: entity-acme
spec:
  cloudAWS:
    awsAccount: "123456789012"
    rbac:
      adminGroup:
        - acme/admins
EOF
```

### Step 5: Create a Team and Assignment
```bash
oc apply -f - <<EOF
apiVersion: hybridsovereign.redhat/v1alpha1
kind: Container
metadata:
  name: platform-team
  namespace: entity-acme
spec:
  team:
    adminGroup:
      - acme/admins
    developerGroup:
      - acme/developers
---
apiVersion: hybridsovereign.redhat/v1alpha1
kind: Assignment
metadata:
  name: platform-team-to-aws
  namespace: entity-acme
spec:
  entity: acme
  ocp:
    - aws-prod
  division:
    - platform-team
  rbac:
    adminGroup:
      - acme/admins
EOF
```

### Apply all sample CRs at once
```bash
make sample-crs-apply
```

---

## Keycloak RBAC Testing

### 1. Check Keycloak groups were created
After `Rbac` CRs are reconciled, check Keycloak:
- URL: `https://keycloak-rhbk.<apps-domain>/auth/admin/sovereign-tenants/groups`
- Groups should appear as `acme/admins`, `acme/developers`

### 2. Check namespace RoleBindings
```bash
oc get rolebinding -n cloudaws-aws-prod
oc get rolebinding -n team-platform-team
```

### 3. Test user access
Assign a Keycloak user to a group, then:
```bash
oc login --username=<user> --server=<cluster>
oc get pods -n cloudaws-aws-prod   # should work for admin group members
```

---

## Pipeline Management

### List all pipeline runs
```bash
oc get pipelinerun -n sovereign-cloud
```

### Trigger build for a single operator
```bash
make trigger-build OPERATOR=<name>
# e.g.:
make trigger-build OPERATOR=entity-operator
make trigger-build OPERATOR=cloudaws-operator
```

### Trigger builds for all operators
```bash
make trigger-build-all
```

### View build logs
```bash
# Get latest PipelineRun name:
PR=$(oc get pipelinerun -n sovereign-cloud -l operator=cloudaws-operator \
  --sort-by=.metadata.creationTimestamp -o name | tail -1)
oc logs -n sovereign-cloud -f $PR --all-containers
```

### Clean up completed PipelineRuns
```bash
oc delete pipelinerun -n sovereign-cloud --field-selector=status.conditions[0].reason=Succeeded
```

---

## ArgoCD Management

### Check custom operator app status
```bash
oc get application.argoproj.io -n openshift-gitops | grep -E "plugin-rbac|entity|cloudaws|cloudoso|platform|team|projects|assignment"
```

### Force sync a specific operator
```bash
oc annotate application.argoproj.io <app-name> -n openshift-gitops \
  argocd.argoproj.io/refresh=normal --overwrite
```

### Check ApplicationSet health
```bash
oc get applicationset -n openshift-gitops
```

---

## Make Targets Reference

### Bootstrap make targets
```bash
make rebuild-all                  # Full platform rebuild from scratch
make phase1-gitops                # Phase 1: GitOps operator + ArgoCD instance
make phase2-applicationset        # Phase 2: Platform ApplicationSet
make deploy-custom-operators      # Deploy custom operator prereqs + ApplicationSet
make trigger-build-all            # Build all 8 custom operator images
make trigger-build OPERATOR=<n>   # Build a single operator image
make wait-custom-operators        # Wait for all operators to be ready
make status                       # Full platform status
make status-custom-operators      # Custom operators status
make sample-crs-apply             # Apply sample CRs for testing
make teardown-bootstrap           # Full teardown (destructive!)
```

---

## Adding a New Operator

1. Create a new GitHub repo under `hybrid-sovereign-cloud/` using the Ansible Operator SDK layout
2. Add a Helm chart at `helm/<operator-name>/`
3. Add an ImageStream Helm chart at `helm/imagestreams/`
4. Add the operator to `bootstrap/charts/gitops/custom-operators-applicationset/values.yaml`
5. Add the operator to `bootstrap/charts/instances/custom-operators-pipelines/values.yaml`
6. Run `make phase2-applicationset` and `make deploy-custom-operators` to deploy
7. Run `make trigger-build OPERATOR=<new-operator>` to build the image
