# Shared helpers for sovereign-init Helm bootstrap layers (operator → secrets → ApplicationSet).

# Cumulative bootstrap layer flags — each target must pass all prior layers as true
# so Helm does not prune resources from earlier make invocations.
SOVEREIGN_INIT_BOOTSTRAP_OPERATOR := --set bootstrap.operator=true
SOVEREIGN_INIT_BOOTSTRAP_SECRETS := $(SOVEREIGN_INIT_BOOTSTRAP_OPERATOR) --set bootstrap.secrets=true
SOVEREIGN_INIT_BOOTSTRAP_APPSET := $(SOVEREIGN_INIT_BOOTSTRAP_SECRETS) --set bootstrap.applicationset=true

# Always derive the bootstrap repo URL from the git remote — never use GITHUB_URL which
# may point to an unrelated repository.  GITHUB_URL remains available for other purposes
# (e.g. Gitea seeding) but must NOT be used as the ArgoCD source for this repository.
BOOTSTRAP_REPO_URL := $(shell git -C "$(CURDIR)" remote get-url origin 2>/dev/null | sed 's|git@github.com:|https://github.com/|')

SOVEREIGN_INIT_HELM_SECRETS_SETS := \
  --set gitops.repoURL="$(BOOTSTRAP_REPO_URL)" \
  --set gitops.token="$(GITHUB_TOKEN)" \
  --set clusters.services.server="$(OCP_SERVICES_SERVER)" \
  --set clusters.services.bearerToken="$$SVC_TOKEN" \
  --set clusters.services.tlsSkipVerify=true \
  --set oci.registry="$(OCI_HOST)" \
  --set oci.namespace="$(OCI_NAMESPACE)" \
  --set oci.robotUsername="$(OCI_ROBOT_USERNAME)" \
  --set oci.robotPassword="$(OCI_ROBOT_PASSWORD)" \
  --set gitea.adminPassword="$(GITEA_ADMIN_PASSWORD)" \
  --set vmware.host="$(VMWARE_HOST)" \
  --set vmware.username="$(VMWARE_USERNAME)" \
  --set vmware.password="$(VMWARE_PASSWORD)" \
  --set vmware.thumbprint="$(VMWARE_THUMBPRINT)"

SOVEREIGN_INIT_HELM_APPSET_SETS := \
  --set gitops.repoURL="$(BOOTSTRAP_REPO_URL)" \
  --set gitops.token="$(GITHUB_TOKEN)"

define sovereign_login_central
	oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1
endef

