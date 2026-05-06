.PHONY: help login import-architecture import-initrepos \
	phase1-gitops phase2-applicationset gitops-full-bootstrap uninstall-platform-applicationset \
	install-aap-operator install-eso-operator install-rhbk-operator \
	install-gitops-operator install-quay-operator install-openshift-pipelines-operator \
	install-all-operators install-all-operators-with-storage \
	install-aap-instance install-vault-instance install-rhbk-instance \
	install-gitops-instance install-gitops-instance-repos install-gitea-instance install-sovereign-cloud \
	install-all-instances install-pipelines-bootstrap \
	wait-openshift-gitops-csv wait-argocd-ready wait-csv-succeeded \
	argocd-post-sync-waits verify-argocd-app-health sync-argocd-app sync-failing-apps fix-argocd-oom fix-registry-redirect setup-rh-registry-pull-secret \
	apply-phase4-samples status-phase4 create-devuser \
	vault-init vault-enable-kv vault-store-gitea-admin vault-store-github-token vault-store-keycloak-auth keycloak-config external-secrets-config fix-csv-operator-groups fix-gitea-scc gitea-setup-entity-credentials \
	install-odf-operator install-odf-noobaa install-quay-instance \
	install-rhacm-operator install-rhacs-operator \
	install-rhacm-instance install-rhacs-instance \
	install-rhacs-config install-rhacm-config \
	wait-rhacm-ready wait-rhacs-ready \
	install-custom-operators-git-creds install-custom-operators-pipelines \
	install-custom-operators-applicationset deploy-custom-operators \
	trigger-build-all trigger-build wait-custom-operators \
	status-custom-operators restart-custom-operators sample-crs-apply \
	uninstall-all-operators uninstall-all-instances uninstall-pipelines-bootstrap \
	teardown-bootstrap delete-bootstrap-namespaces approve-rhbk-installplan status \
	validate-helm verify-pipelines-bootstrap rebuild-all \
	enable-dynamic-plugins install-dynamic-plugins-config enable-sovereign-console-plugin \
	trigger-build-console wait-console-build deploy-console \
	fix-acs-consoleplugin debug-acs-consoleplugin regenerate-acs-init-bundle \
	oci-login oci-push-all oci-push-bootstrap oci-push-operators oci-make-public \
	uninstall-aap-operator uninstall-eso-operator uninstall-rhbk-operator \
	uninstall-gitops-operator uninstall-quay-operator uninstall-openshift-pipelines-operator \
	uninstall-odf-operator uninstall-odf-noobaa uninstall-quay-instance \
	uninstall-rhacm-operator uninstall-rhacs-operator \
	uninstall-rhacm-instance uninstall-rhacs-instance \
	uninstall-rhacs-config uninstall-rhacm-config \
	uninstall-sovereign-cloud uninstall-aap-instance uninstall-vault-instance \
	uninstall-rhbk-instance uninstall-gitea-instance \
	uninstall-vault-init uninstall-keycloak-config uninstall-external-secrets-config \
	uninstall-service-oidc-config uninstall-dynamic-plugins-config \
	uninstall-custom-operators-git-creds uninstall-custom-operators-pipelines \
	uninstall-custom-operators-applicationset \
	install-entity-operator uninstall-entity-operator \
	install-cloudaws-operator uninstall-cloudaws-operator \
	install-cloudoso-operator uninstall-cloudoso-operator \
	install-platformopenshift-operator uninstall-platformopenshift-operator \
	install-team-operator uninstall-team-operator \
	install-projects-operator uninstall-projects-operator \
	install-assignment-operator uninstall-assignment-operator \
	install-plugin-rbac uninstall-plugin-rbac \
	install-sovereign-cloud-console uninstall-sovereign-cloud-console \
	wait-argoapp sync-wait-argoapp teardown-all-argocd-apps

SHELL := /bin/bash

# Source user shell profile (PATH, aliases) — optional for automation.
SOURCE_BASHRC := { set +eu; . $${HOME}/.bashrc 2>/dev/null; set -eu; } 2>/dev/null || true
WAIT_INTERVAL ?= 15
WAIT_ATTEMPTS ?= 120

# ---------------------------------------------------------------------------
# TLS / SSL flags
# Set INSECURE_SKIP_TLS=true (default) to tolerate self-signed / lab certs.
# Propagated to: oc login, helm (via kubeconfig), curl calls.
# ---------------------------------------------------------------------------
INSECURE_SKIP_TLS ?= true
OC_INSECURE       := $(if $(filter true,$(INSECURE_SKIP_TLS)),--insecure-skip-tls-verify,)
HELM_INSECURE     := $(if $(filter true,$(INSECURE_SKIP_TLS)),--kube-insecure-skip-tls-verify,)
CURL_INSECURE     := $(if $(filter true,$(INSECURE_SKIP_TLS)),-k,)

# Git remote for Argo CD + ApplicationSet (HTTPS URL with org/repo). Personal access token required.
GITHUB_URL ?=
GITHUB_TOKEN ?=
GITHUB_REVISION ?= main
export GITHUB_REVISION

# ---------------------------------------------------------------------------
# OCI Registry (Phase 1)
# OCI_REGISTRY_TOKEN loaded from ~/.bashrc (export OCI_REGISTRY_TOKEN=...)
# OCI_REGISTRY_HOST  — quay.io (no scheme, no trailing slash)
# OCI_ORG            — quay.io organisation name
# OCI_HELM_REGISTRY  — oci:// prefix used by helm push / ArgoCD Application source
# CHART_VERSION      — version used when packaging and referencing charts
# ---------------------------------------------------------------------------
OCI_REGISTRY_HOST  ?= quay.io
OCI_ORG            ?= sovereignhybrid
OCI_HELM_REGISTRY  ?= oci://$(OCI_REGISTRY_HOST)/$(OCI_ORG)
CHART_VERSION      ?= 0.1.0
SCRIPTS_DIR        := scripts

# Directories
DESIGN_DIR    := design
INIT_DIR      := init
CHARTS_DIR    := charts

# Repos
ARCH_REPO     := git@github.com:hybrid-sovereign-cloud/architecture.git
ARCH_DIR      := $(DESIGN_DIR)/architecture
BASE_CHART_REPO := git@github.com:hybrid-sovereign-cloud/base_chart.git
BASE_CHART_DIR  := $(INIT_DIR)/base_chart

# Operator chart paths
AAP_OP_CHART   := $(CHARTS_DIR)/operators/aap-operator
ESO_OP_CHART   := $(CHARTS_DIR)/operators/external-secrets-operator
RHBK_OP_CHART  := $(CHARTS_DIR)/operators/rhbk-operator
GITOPS_OP_CHART := $(CHARTS_DIR)/operators/gitops-operator
QUAY_OP_CHART  := $(CHARTS_DIR)/operators/quay-operator
ODF_OP_CHART   := $(CHARTS_DIR)/operators/odf-operator
PIPELINES_OP_CHART := $(CHARTS_DIR)/operators/openshift-pipelines-operator
RHACM_OP_CHART := $(CHARTS_DIR)/operators/rhacm-operator
RHACS_OP_CHART := $(CHARTS_DIR)/operators/rhacs-operator

# Instance chart paths
AAP_INST_CHART    := $(CHARTS_DIR)/instances/aap-instance
VAULT_INST_CHART  := $(CHARTS_DIR)/instances/vault-instance
RHBK_INST_CHART   := $(CHARTS_DIR)/instances/rhbk-instance
GITOPS_INST_CHART := $(CHARTS_DIR)/instances/gitops-instance
GITEA_INST_CHART  := $(CHARTS_DIR)/instances/gitea-instance
SC_CHART          := $(CHARTS_DIR)/instances/sovereign-cloud
QUAY_INST_CHART   := $(CHARTS_DIR)/instances/quay-instance
PIPELINES_BOOT_CHART := $(CHARTS_DIR)/instances/pipelines-bootstrap
RHACM_INST_CHART  := $(CHARTS_DIR)/instances/rhacm-instance
RHACS_INST_CHART  := $(CHARTS_DIR)/instances/rhacs-instance
GITOPS_APPS_CHART     := $(CHARTS_DIR)/gitops/platform-applicationset
CUSTOM_OPS_APPSET_CHART   := $(CHARTS_DIR)/gitops/custom-operators-applicationset
CUSTOM_OPS_PIPELINES_CHART := $(CHARTS_DIR)/instances/custom-operators-pipelines
CUSTOM_OPS_GIT_CREDS_CHART := $(CHARTS_DIR)/instances/custom-operators-git-creds

# Config chart paths
VAULT_INIT_CHART  := $(CHARTS_DIR)/config/vault-init
KC_CONFIG_CHART   := $(CHARTS_DIR)/config/keycloak-config
ESO_CONFIG_CHART  := $(CHARTS_DIR)/config/external-secrets-config
RHACS_CONFIG_CHART := $(CHARTS_DIR)/config/rhacs-config
RHACM_CONFIG_CHART := $(CHARTS_DIR)/config/rhacm-config

# Namespaces managed by this bootstrap (for teardown). Optional: DELETE_OPENSHIFT_STORAGE_NS=1
BOOTSTRAP_NAMESPACES := ansible-automation-platform external-secrets-operator \
	rhbk openshift-gitops quay vault aap gitea sovereign-cloud sovereign-cloud-plugins \
	open-cluster-management open-cluster-management-hub open-cluster-management-agent \
	open-cluster-management-agent-addon rhacs-operator stackrox

##@ Help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-32s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Phased GitOps bootstrap
phase1-gitops: ## Phase 1: cluster-scoped GitOps operator + Argo CD repo secret (needs GITHUB_URL, GITHUB_TOKEN)
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	$(MAKE) login; \
	$(MAKE) install-gitops-operator; \
	$(MAKE) wait-openshift-gitops-csv; \
	$(MAKE) install-gitops-instance-repos; \
	$(MAKE) wait-argocd-ready

phase2-applicationset: ## Phase 2: install platform ApplicationSet into openshift-gitops (needs login, GITHUB_URL, apps domain)
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	$(MAKE) login; \
	test -n "$${GITHUB_URL:-}" || { echo "GITHUB_URL must point at the Git repo containing this bootstrap (HTTPS)."; exit 1; }; \
	APPS_DOMAIN=$${APPS_DOMAIN_OVERRIDE:-$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')}; \
	test -n "$$APPS_DOMAIN" || { echo "Could not read cluster apps domain from ingresses.config.openshift.io/cluster."; exit 1; }; \
	echo "Using apps domain: $$APPS_DOMAIN"; \
	helm upgrade --install $(HELM_INSECURE) platform-applicationset $(GITOPS_APPS_CHART) \
		--namespace openshift-gitops --create-namespace \
		--set-string appsDomain="$$APPS_DOMAIN" \
		--set-string git.repoURL="$$GITHUB_URL" \
		--set-string git.revision="$${GITHUB_REVISION:-main}" \
		--set-string githubToken="$${GITHUB_TOKEN:-}"

gitops-full-bootstrap: phase1-gitops phase2-applicationset ## Run phase1 then phase2

rebuild-all: ## Full platform rebuild on a brand new cluster (Phase 1→2→vault→keycloak→custom-operators)
	@echo "================================================================"
	@echo "  HYBRID SOVEREIGN CLOUD — Full Platform Rebuild"
	@echo "================================================================"
	$(MAKE) phase1-gitops
	# phase1-gitops applies gitops-instance chart; apply again to ensure resourceExclusions are current
	$(MAKE) install-gitops-instance
	$(MAKE) phase2-applicationset
	@echo "==> Waiting for ArgoCD to reconcile operators (60s)..."
	@sleep 60
	$(MAKE) vault-enable-kv
	$(MAKE) vault-store-gitea-admin
	$(MAKE) vault-store-github-token
	$(MAKE) fix-csv-operator-groups
	$(MAKE) fix-gitea-scc
	$(MAKE) keycloak-config
	$(MAKE) vault-store-keycloak-auth
	$(MAKE) external-secrets-config
	$(MAKE) deploy-custom-operators
	$(MAKE) enable-dynamic-plugins
	@echo "================================================================"
	@echo "  Rebuild complete. Run 'make status' to verify all components."
	@echo "================================================================"

##@ Dynamic Plugins

enable-dynamic-plugins: ## Enable all dynamic console plugins (idempotent patch on consoles.operator.openshift.io)
	@echo "==> Enabling dynamic console plugins..."
	@PLUGINS=$$(oc get consoleplugins -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null); \
	CURRENT=$$(oc get consoles.operator.openshift.io cluster -o jsonpath='{.spec.plugins}' 2>/dev/null || echo "[]"); \
	MERGED=$$(python3 -c "import json,sys; e=json.loads(sys.argv[1]) if sys.argv[1] not in ('','[]','null') else []; d=sys.argv[2].split(); m=list(dict.fromkeys(e+d)); print(json.dumps(m))" "$$CURRENT" "$$PLUGINS"); \
	echo "Patching with plugins: $$MERGED"; \
	oc patch consoles.operator.openshift.io cluster --type=merge -p "{\"spec\":{\"plugins\":$$MERGED}}"
	@echo "==> Current enabled plugins:"
	@oc get consoles.operator.openshift.io cluster -o jsonpath='{.spec.plugins}' 2>/dev/null; echo ""

install-dynamic-plugins-config: ## Deploy dynamic-plugins-config via ArgoCD Application (OCI helm) — see GitOps Applications section

enable-sovereign-console-plugin: ## Enable the sovereign-cloud-plugin in consoles.operator.openshift.io cluster
	@echo "==> Adding sovereign-cloud-plugin to enabled plugins..."
	@CURRENT=$$(oc get consoles.operator.openshift.io cluster -o jsonpath='{.spec.plugins}' 2>/dev/null || echo "[]"); \
	MERGED=$$(python3 -c "import json,sys; e=json.loads(sys.argv[1]) if sys.argv[1] not in ('','[]','null') else []; p='sovereign-cloud-plugin'; e=e+[p] if p not in e else e; print(json.dumps(e))" "$$CURRENT"); \
	echo "Patching with plugins: $$MERGED"; \
	oc patch consoles.operator.openshift.io cluster --type=merge -p "{\"spec\":{\"plugins\":$$MERGED}}"

deploy-console: trigger-build-console wait-build-console install-sovereign-cloud-console ## Build console, wait, then deploy via ArgoCD

##@ Cluster Access
login: ## Login to OpenShift (uses OCP_*; loads ./.env if present)
	@set -euo pipefail; \
	set -a; [ -f .env ] && . ./.env || true; set +a; \
	if [ -z "$${OCP_SERVER:-}" ] || [ -z "$${OCP_USERNAME:-}" ] || [ -z "$${OCP_PASSWORD:-}" ]; then \
		echo "Missing OCP_SERVER, OCP_USERNAME, or OCP_PASSWORD." >&2; \
		echo "Copy .env.example to .env in this directory, or export the variables." >&2; \
		echo "Cursor Cloud Agents: add the same three names in Dashboard → Cloud Agents → Secrets." >&2; \
		exit 1; \
	fi; \
	oc login "$$OCP_SERVER" -u "$$OCP_USERNAME" -p "$$OCP_PASSWORD" $(OC_INSECURE)

##@ Import
import-architecture: ## Clone/pull architecture repo into design/
	@if [ -d "$(ARCH_DIR)" ]; then \
		echo "Architecture repo exists, pulling latest..."; \
		cd $(ARCH_DIR) && git pull; \
	else \
		mkdir -p $(DESIGN_DIR); \
		git clone $(ARCH_REPO) $(ARCH_DIR); \
	fi

import-initrepos: ## Clone/pull base_chart repo into init/
	@if [ -d "$(BASE_CHART_DIR)" ]; then \
		echo "base_chart repo exists, pulling latest..."; \
		cd $(BASE_CHART_DIR) && git pull; \
	else \
		mkdir -p $(INIT_DIR); \
		git clone $(BASE_CHART_REPO) $(BASE_CHART_DIR); \
	fi

##@ Validate (no cluster required)
validate-helm: ## Helm-template all charts to catch YAML/chart errors
	@set -euo pipefail; \
	for c in $$(find $(CHARTS_DIR) -name Chart.yaml -printf '%h\n' | sort -u); do \
		echo "==> $$c"; \
		NS=sovereign-cloud; \
		EXTRA=""; \
		echo "$$c" | grep -q 'operators/openshift-pipelines-operator' && NS=openshift-operators; \
		echo "$$c" | grep -q 'gitops/platform-applicationset' && NS=openshift-gitops && EXTRA='--set appsDomain=apps.validate.example.com'; \
		echo "$$c" | grep -q 'gitops/argocd-init-job' && NS=openshift-gitops; \
		helm template test-release "$$c" --namespace $$NS $$EXTRA >/dev/null; \
	done; \
	echo "All charts rendered OK."

##@ Operators (Phase 2 — defined in GitOps Applications section below)
# install-gitops-operator is kept here as Phase 1 direct OCI install (bootstraps ArgoCD)
# All other operator installs are Phase 2 ArgoCD Applications defined further below.

install-gitops-operator: ## Install OpenShift GitOps operator from OCI registry (Phase 1 direct install)
	@$(SOURCE_BASHRC); \
	helm upgrade --install $(HELM_INSECURE) gitops-operator \
		$(OCI_HELM_REGISTRY)/gitops-operator \
		--version $(CHART_VERSION) \
		--namespace openshift-gitops --create-namespace

uninstall-gitops-operator: ## Uninstall GitOps operator helm release
	@$(SOURCE_BASHRC); \
	helm uninstall gitops-operator -n openshift-gitops --ignore-not-found 2>/dev/null || true; \
	oc delete subscription openshift-gitops-operator -n openshift-operators --ignore-not-found 2>/dev/null || true; \
	oc delete csv -n openshift-gitops -l operators.coreos.com/openshift-gitops-operator.openshift-gitops --ignore-not-found 2>/dev/null || true

install-all-operators: install-aap-operator install-eso-operator install-rhbk-operator install-quay-operator install-openshift-pipelines-operator ## Install core operators via ArgoCD Applications (OCI helm)

install-all-operators-with-storage: install-all-operators install-odf-operator ## All operators plus ODF

approve-rhbk-installplan: ## Legacy: approve RHBK InstallPlan only if still Manual (chart uses Automatic by default)
	@ip=$$(oc get installplan -n rhbk -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null); \
	if [ -n "$$ip" ]; then \
		echo "Approving RHBK InstallPlan: $$ip"; \
		oc patch installplan $$ip -n rhbk --type merge -p '{"spec":{"approved":true}}'; \
	else \
		echo "No pending RHBK InstallPlan to approve."; \
	fi

##@ Waits / GitOps health (retry loops)
wait-openshift-gitops-csv: ## Retry until openshift-gitops operator CSV is Succeeded
	@n=0; \
	until csv=$$(oc get csv -n openshift-gitops -o name 2>/dev/null | grep openshift-gitops-operator | head -1); \
		[ -n "$$csv" ] && [ "$$(oc get "$$csv" -n openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null)" = "Succeeded" ]; do \
	  n=$$((n+1)); echo "waiting openshift-gitops CSV ($$n/$(WAIT_ATTEMPTS))"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; \
	echo "openshift-gitops CSV succeeded"

wait-argocd-ready: ## Retry until ArgoCD CR openshift-gitops reports Available/Completed phase
	@n=0; \
	until phase=$$(oc get argocd openshift-gitops -n openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null || true); \
		[ "$$phase" = "Available" ] || [ "$$phase" = "Completed" ]; do \
	  n=$$((n+1)); echo "waiting ArgoCD ($$n/$(WAIT_ATTEMPTS)) phase=$${phase:-missing}"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; \
	echo "ArgoCD openshift-gitops ready"

verify-argocd-app-health: ## Exits 0 when Application APP is Healthy (APP= required)
	@test -n "$(APP)" || { echo "Usage: make verify-argocd-app-health APP=vault-init"; exit 1; }
	@oc get applications.argoproj.io "$(APP)" -n openshift-gitops -o jsonpath='{.status.health.status}' | grep -qx Healthy

sync-argocd-app: ## Force ArgoCD hard-sync for APP= (replace=false by default; set REPLACE=true to delete+recreate)
	@test -n "$(APP)" || { echo "Usage: make sync-argocd-app APP=entity-operator [REPLACE=true]"; exit 1; }
	@echo "==> Hard syncing ArgoCD app: $(APP)"
	@PATCH='{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}},"prune":true}}}'; \
	oc patch applications.argoproj.io "$(APP)" -n openshift-gitops --type=merge -p "$$PATCH"
	@echo "==> Waiting for $(APP) sync to complete (up to 5m)..."
	@for i in $$(seq 1 30); do \
	  SYNC=$$(oc get applications.argoproj.io "$(APP)" -n openshift-gitops -o jsonpath='{.status.sync.status}' 2>/dev/null); \
	  HEALTH=$$(oc get applications.argoproj.io "$(APP)" -n openshift-gitops -o jsonpath='{.status.health.status}' 2>/dev/null); \
	  echo "  [$$i/30] sync=$$SYNC health=$$HEALTH"; \
	  [ "$$SYNC" = "Synced" ] && [ "$$HEALTH" = "Healthy" ] && { echo "$(APP): Synced+Healthy"; exit 0; }; \
	  sleep 10; \
	done; echo "WARNING: $(APP) did not reach Synced+Healthy in 5m"

setup-rh-registry-pull-secret: ## Copy global Red Hat Registry pull secret to sovereign-cloud namespace for pipeline builds
	@$(SOURCE_BASHRC); \
	echo "==> Copying global pull secret to sovereign-cloud namespace..."; \
	DOCKER_CFG=$$(oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}'); \
	echo "{\"apiVersion\":\"v1\",\"kind\":\"Secret\",\"metadata\":{\"name\":\"rh-registry-pull-secret\",\"namespace\":\"sovereign-cloud\"},\"type\":\"kubernetes.io/dockerconfigjson\",\"data\":{\".dockerconfigjson\":\"$$DOCKER_CFG\"}}" | oc apply -f -; \
	oc secrets link pipeline rh-registry-pull-secret -n sovereign-cloud 2>/dev/null || true; \
	oc secrets link pipeline rh-registry-pull-secret --for=pull -n sovereign-cloud 2>/dev/null || true; \
	echo "==> Red Hat Registry pull secret configured for pipeline SA"

fix-registry-redirect: ## Disable internal image registry blob redirect (fixes 403 from Swift storage backend)
	@$(SOURCE_BASHRC); \
	echo "==> Disabling image registry blob redirect (Swift 403 workaround)..."; \
	oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge \
	  -p '{"spec":{"disableRedirect":true,"defaultRoute":true}}'; \
	echo "==> Waiting for registry rollout..."; \
	oc rollout status deployment/image-registry -n openshift-image-registry --timeout=120s

fix-argocd-oom: ## Increase ArgoCD application-controller memory to 6Gi (fixes OOMKill with many large operators)
	@echo "==> Patching ArgoCD CR controller.resources to 6Gi..."
	@oc patch argocd openshift-gitops -n openshift-gitops --type=merge \
	  -p '{"spec":{"controller":{"resources":{"limits":{"cpu":"4","memory":"6Gi"},"requests":{"cpu":"500m","memory":"2Gi"}}}}}'
	@echo "==> Waiting 10s for ArgoCD operator to reconcile StatefulSet..."
	@sleep 10
	@echo "==> Current StatefulSet limits:"
	@oc get statefulset openshift-gitops-application-controller -n openshift-gitops \
	  -o jsonpath='{.spec.template.spec.containers[0].resources}' 2>/dev/null | python3 -m json.tool || true
	@echo "==> Deleting application-controller pod to force fresh restart with new memory limits..."
	@oc delete pod openshift-gitops-application-controller-0 -n openshift-gitops --grace-period=5 2>/dev/null || true
	@echo "==> Waiting for application-controller pod to restart (up to 5m)..."
	@for i in $$(seq 1 30); do \
	  STATUS=$$(oc get pod openshift-gitops-application-controller-0 -n openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null); \
	  READY=$$(oc get pod openshift-gitops-application-controller-0 -n openshift-gitops -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null); \
	  MEM=$$(oc get pod openshift-gitops-application-controller-0 -n openshift-gitops -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null); \
	  echo "  [$$i/30] status=$$STATUS ready=$$READY memory=$$MEM"; \
	  [ "$$READY" = "true" ] && { echo "application-controller is Ready with $$MEM memory limit"; exit 0; }; \
	  sleep 10; \
	done; echo "WARNING: application-controller not ready in 5m, check: oc describe pod/openshift-gitops-application-controller-0 -n openshift-gitops"

sync-failing-apps: ## Force sync all OutOfSync ArgoCD apps
	@echo "==> Syncing all OutOfSync applications..."
	@for app in $$(oc get applications.argoproj.io -n openshift-gitops --no-headers 2>/dev/null | grep -v "Synced" | awk '{print $$1}'); do \
	  echo "  Syncing: $$app"; \
	  PATCH='{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}},"prune":true}}}'; \
	  oc patch applications.argoproj.io "$$app" -n openshift-gitops --type=merge -p "$$PATCH" 2>/dev/null || true; \
	done
	@echo "==> Waiting 60s then showing status..."
	@sleep 60
	@oc get applications.argoproj.io -n openshift-gitops --no-headers 2>&1 | head -40

argocd-post-sync-waits: ## Wait for vault-init, keycloak-config, external-secrets-config Applications (GitOps)
	@set -e; \
	for app in vault-init keycloak-config external-secrets-config; do \
	  n=0; \
	  until oc get applications.argoproj.io "$$app" -n openshift-gitops -o jsonpath='{.status.health.status}' 2>/dev/null | grep -qx Healthy; do \
	    n=$$((n+1)); echo "waiting $$app Healthy ($$n/$(WAIT_ATTEMPTS))"; \
	    [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	  done; \
	  echo "$$app: Healthy"; \
	done

##@ Instances (Phase 2 — defined in GitOps Applications section below)
# install-gitops-instance is kept here as Phase 1 direct OCI install (bootstraps ArgoCD)
# All other instance installs are Phase 2 ArgoCD Applications defined further below.

install-gitops-instance: ## Apply gitops-instance chart from OCI (Phase 1 — direct install, sets up ArgoCD + OCI creds)
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env || true; set +a; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo ""); \
	helm upgrade --install $(HELM_INSECURE) gitops-instance \
		$(OCI_HELM_REGISTRY)/gitops-instance \
		--version $(CHART_VERSION) \
		--namespace openshift-gitops --create-namespace \
		$${APPS_DOMAIN:+--set argocd.appsDomain="$$APPS_DOMAIN"} \
		$${GITHUB_URL:+--set-string github.repositoryUrl="$$GITHUB_URL"} \
		$${GITHUB_TOKEN:+--set-string github.token="$$GITHUB_TOKEN"} \
		$${GITHUB_URL:+--set-string github.insecure="true"} \
		$${GITHUB_URL:+--set-string github.username="git"} \
		$${OCI_REGISTRY_TOKEN:+--set-string ociRegistry.token="$$OCI_REGISTRY_TOKEN"}

install-gitops-instance-repos: ## Configure Argo CD repository secret via OCI gitops-instance chart (Phase 1)
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$${GITHUB_URL:-}" && test -n "$${GITHUB_TOKEN:-}" || { echo "Set GITHUB_URL and GITHUB_TOKEN (e.g. in .env)."; exit 1; }; \
	$(MAKE) install-gitops-instance

install-all-instances: install-sovereign-cloud install-aap-instance install-vault-instance install-rhbk-instance ## Install core instances via ArgoCD Applications (OCI helm)

##@ Configuration
vault-init: ## Initialize Vault, create unseal secret, central KV
	@echo "==> Running vault-init via ArgoCD-managed chart (render + apply job directly)"
	@APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	helm template vault-init $(VAULT_INIT_CHART) \
		--namespace vault \
		--set "vaultAddr=http://central-vault.vault.svc:8200" | \
		oc apply -n vault -f - 2>&1 || true; \
	echo "==> Waiting for vault-init job..."; \
	oc wait --for=condition=complete job/vault-init -n vault --timeout=120s 2>/dev/null || \
	  oc logs -n vault job/vault-init --tail=20 2>/dev/null | tail -10

vault-store-keycloak-auth: ## Store keycloak-auth-config in Vault using master realm admin (temp-admin)
	@ROOT_TOKEN=$$(oc get secret vault-init-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d); \
	KC_USER=$$(oc get secret central-keycloak-initial-admin -n rhbk -o jsonpath='{.data.username}' | base64 -d); \
	KC_PASS=$$(oc get secret central-keycloak-initial-admin -n rhbk -o jsonpath='{.data.password}' | base64 -d); \
	KC_HOST=$$(oc get route -n rhbk -l app=keycloak -o jsonpath='{.items[0].spec.host}'); \
	KC_URL="https://$$KC_HOST"; \
	if [ -z "$$KC_HOST" ]; then echo "ERROR: Keycloak route not found in rhbk namespace"; exit 1; fi; \
	oc exec -n vault central-vault-0 -- sh -c \
	  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$ROOT_TOKEN vault kv put central/keycloak/auth-config \
	   KC_USERNAME='$$KC_USER' KC_PASSWORD='$$KC_PASS' KC_REALM=sovereign-tenants KC_AUTH_REALM=master KC_URL='$$KC_URL'" && \
	echo "Stored keycloak-auth-config in Vault (master realm admin: $$KC_USER, url: $$KC_URL)"

vault-store-gitea-admin: ## Store Gitea admin credentials in Vault (generates random password if not set)
	@ROOT_TOKEN=$$(oc get secret vault-init-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d); \
	VAULT_ADDR="http://central-vault.vault.svc:8200"; \
	GITEA_PASS=$$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 24 2>/dev/null || openssl rand -hex 12); \
	oc exec -n vault central-vault-0 -- sh -c \
	  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$ROOT_TOKEN vault kv get central/gitea/admin > /dev/null 2>&1 \
	   || (VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$ROOT_TOKEN vault kv put central/gitea/admin username=gitea-admin password=$$GITEA_PASS \
	   && echo 'Gitea admin secret stored in Vault')"

vault-store-github-token: ## Store GitHub PAT in Vault at central/github/token (requires GITHUB_TOKEN env var)
	@test -n "$${GITHUB_TOKEN:-}" || { echo "ERROR: GITHUB_TOKEN not set"; exit 1; }; \
	ROOT_TOKEN=$$(oc get secret vault-init-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d); \
	oc exec -n vault central-vault-0 -- sh -c \
	  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$ROOT_TOKEN vault kv put central/github token='$${GITHUB_TOKEN}'" && \
	echo "Stored GitHub token in Vault"

fix-csv-operator-groups: ## Fix CSVs missing the olm.operatorgroup.uid annotation (NoOperatorGroup issue)
	@echo "==> Fixing CSVs with NoOperatorGroup issue..."
	@for ns_og_csv in \
	  "ansible-automation-platform,ansible-automation-platform-og" \
	  "external-secrets-operator,external-secrets-operator-og" \
	  "open-cluster-management,open-cluster-management-og" \
	  "rhacs-operator,rhacs-operator-og" \
	  "rhbk,rhbk-og"; do \
	  NS=$$(echo $$ns_og_csv | cut -d',' -f1); \
	  OG=$$(echo $$ns_og_csv | cut -d',' -f2); \
	  OG_UID=$$(oc get operatorgroup $$OG -n $$NS -o jsonpath='{.metadata.uid}' 2>/dev/null); \
	  [ -z "$$OG_UID" ] && continue; \
	  for CSV in $$(oc get csv -n $$NS -o name 2>/dev/null | sed 's|.*/||'); do \
	    REASON=$$(oc get csv $$CSV -n $$NS -o jsonpath='{.status.reason}' 2>/dev/null); \
	    if [ "$$REASON" = "NoOperatorGroup" ]; then \
	      echo "  Patching $$CSV in $$NS with OG $$OG (uid=$$OG_UID)"; \
	      oc patch csv $$CSV -n $$NS --type=merge -p "{\"metadata\":{\"annotations\":{\"olm.operatorgroup.uid\":\"$$OG_UID\",\"olm.operatorgroup\":\"$$OG\"}}}" 2>&1 | head -1; \
	    fi; \
	  done; \
	done; \
	echo "==> Done fixing CSV OperatorGroup annotations"

vault-enable-kv: ## Enable central KV engine in Vault (idempotent)
	@ROOT_TOKEN=$$(oc get secret vault-init-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d); \
	oc exec -n vault central-vault-0 -- sh -c \
	  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$ROOT_TOKEN vault secrets list -format=json 2>/dev/null | grep -q '\"central/\"' \
	   || (VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$ROOT_TOKEN vault secrets enable -path=central -version=2 kv && echo 'KV enabled') \
	   && echo 'central KV ready'"

keycloak-config: ## Configure Keycloak realm, users, clients, store secrets in Vault
	@APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	helm template keycloak-config $(KC_CONFIG_CHART) \
		--namespace rhbk \
		--set "keycloakUrl=https://keycloak-rhbk.$$APPS_DOMAIN" | \
		oc apply -n rhbk -f - 2>&1 | grep -v 'unchanged\|configured' || true; \
	echo "==> Waiting for keycloak-config job..."; \
	sleep 5; \
	for i in 1 2 3 4 5 6 7 8 9 10 11 12; do \
	  PHASE=$$(oc get job keycloak-config -n rhbk -o jsonpath='{.status.conditions[0].type}' 2>/dev/null); \
	  [ "$$PHASE" = "Complete" ] && echo "keycloak-config job completed." && break; \
	  echo "  Waiting ($$i/12)..."; sleep 10; \
	done; \
	oc logs -n rhbk job/keycloak-config --tail=20 2>/dev/null | tail -15

external-secrets-config: ## Configure ExternalSecrets + SecretStore
	helm template eso-config $(ESO_CONFIG_CHART) \
		--namespace sovereign-cloud | \
		oc apply -f - 2>&1 | grep -v 'unchanged\|configured' || true

##@ ODF, Quay, RHACM, RHACS (Phase 2 — defined in GitOps Applications section below)
# All installs are Phase 2 ArgoCD Applications referencing OCI Helm charts.

wait-rhacm-ready: ## Wait for MultiClusterHub to reach Running phase
	@set -e; n=0; \
	until oc get multiclusterhub multiclusterhub -n open-cluster-management \
	  -o jsonpath='{.status.phase}' 2>/dev/null | grep -qx Running; do \
	  n=$$((n+1)); echo "waiting MultiClusterHub Running ($$n/$(WAIT_ATTEMPTS))"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; echo "MultiClusterHub: Running"

wait-rhacs-ready: ## Wait for ACS Central to be deployed
	@set -e; n=0; \
	until oc get central stackrox-central-services -n stackrox \
	  -o jsonpath='{.status.conditions[?(@.type=="Deployed")].status}' 2>/dev/null | grep -qi true; do \
	  n=$$((n+1)); echo "waiting ACS Central Deployed ($$n/$(WAIT_ATTEMPTS))"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; echo "ACS Central: Deployed"

##@ Pipelines verify (read-only oc)
verify-pipelines-bootstrap: ## Show Pipeline + ImageStream (requires login); start runs from console/tkn
	oc get pipeline,imagestream -n sovereign-cloud

##@ Uninstall (Phase 2 — defined in GitOps Applications section below)
# All uninstall-* and teardown-* targets are defined in the GitOps Applications section.

uninstall-platform-applicationset: ## Remove legacy ApplicationSet Helm release (if still present)
	-helm uninstall platform-applicationset -n openshift-gitops
	-oc delete applicationset.argoproj.io platform-gitops -n openshift-gitops --ignore-not-found

delete-bootstrap-namespaces: ## Delete bootstrap namespaces (destructive; set CONFIRM_CLUSTER_RESET=1)
	@if [ "$$CONFIRM_CLUSTER_RESET" != "1" ]; then \
		echo "Refusing: set CONFIRM_CLUSTER_RESET=1 to delete namespaces: $(BOOTSTRAP_NAMESPACES)"; \
		exit 1; \
	fi
	@for ns in $(BOOTSTRAP_NAMESPACES); do \
		echo "Deleting namespace $$ns ..."; \
		oc delete namespace "$$ns" --wait=false 2>/dev/null || true; \
	done
	@if [ "$$DELETE_OPENSHIFT_STORAGE_NS" = "1" ]; then \
		echo "Deleting openshift-storage ..."; \
		oc delete namespace openshift-storage --wait=false 2>/dev/null || true; \
	else \
		echo "Skipping openshift-storage (set DELETE_OPENSHIFT_STORAGE_NS=1 to remove ODF namespace)."; \
	fi
	@echo "==> Fixing stuck RHACM/HyperShift/MulticlusterEngine webhook CRDs to prevent ArgoCD cache blocking..."
	@for crd in clustermanagementaddons.addon.open-cluster-management.io \
	            managedclusteraddons.addon.open-cluster-management.io \
	            agentclassifications.agent-install.openshift.io \
	            agents.agent-install.openshift.io \
	            infraenvs.agent-install.openshift.io; do \
	  oc patch crd $$crd --type=json \
	    -p='[{"op":"replace","path":"/spec/conversion/strategy","value":"None"},{"op":"remove","path":"/spec/conversion/webhook"}]' \
	    2>/dev/null || true; \
	done
	@echo "==> Force-removing finalizers from terminating namespaces..."
	@for ns in $(BOOTSTRAP_NAMESPACES); do \
	  STATUS=$$(oc get ns $$ns -o jsonpath='{.status.phase}' 2>/dev/null); \
	  if [ "$$STATUS" = "Terminating" ]; then \
	    oc get namespace $$ns -o json 2>/dev/null | \
	      python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" | \
	      oc replace --raw /api/v1/namespaces/$$ns/finalize -f - > /dev/null 2>&1 || true; \
	  fi; \
	done

##@ Custom Operators (Phase 2 — defined in GitOps Applications section below)
# install-custom-operators-git-creds, install-custom-operators-pipelines, and per-operator
# targets are Phase 2 ArgoCD Applications defined further below.

fix-gitea-scc: ## Grant anyuid SCC to Gitea default SA (needed for init-directories chmod)
	@oc adm policy add-scc-to-user anyuid -z default -n gitea 2>&1 || true
	@oc rollout restart deployment gitea -n gitea 2>&1 || true
	@echo "Gitea anyuid SCC granted and rollout restarted"

gitea-setup-entity-credentials: ## Create Gitea org, repo, token for entity-operator git sync
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	GITEA_ROUTE=$$(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null); \
	GITEA_ADMIN_USER=$$(oc get secret gitea-admin-secret -n gitea -o jsonpath='{.data.username}' 2>/dev/null | base64 -d); \
	GITEA_ADMIN_PASS=$$(oc get secret gitea-admin-secret -n gitea -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
	echo "==> Creating Gitea org 'cloud' and repo 'git_resources'..."; \
	curl -sk -X POST "https://$$GITEA_ROUTE/api/v1/orgs" \
	  -u "$$GITEA_ADMIN_USER:$$GITEA_ADMIN_PASS" \
	  -H "Content-Type: application/json" \
	  -d '{"username":"cloud","visibility":"public"}' > /dev/null 2>&1 || true; \
	curl -sk -X POST "https://$$GITEA_ROUTE/api/v1/orgs/cloud/repos" \
	  -u "$$GITEA_ADMIN_USER:$$GITEA_ADMIN_PASS" \
	  -H "Content-Type: application/json" \
	  -d '{"name":"git_resources","private":false,"auto_init":true}' > /dev/null 2>&1 || true; \
	echo "==> Creating Gitea API token for entity-operator..."; \
	curl -sk -X DELETE "https://$$GITEA_ROUTE/api/v1/users/$$GITEA_ADMIN_USER/tokens/entity-op-rw" \
	  -u "$$GITEA_ADMIN_USER:$$GITEA_ADMIN_PASS" 2>/dev/null || true; \
	TOKEN_JSON=$$(curl -sk -X POST "https://$$GITEA_ROUTE/api/v1/users/$$GITEA_ADMIN_USER/tokens" \
	  -u "$$GITEA_ADMIN_USER:$$GITEA_ADMIN_PASS" \
	  -H "Content-Type: application/json" \
	  -d '{"name":"entity-op-rw","scopes":["write:repository","write:organization","read:user"]}'); \
	NEW_TOKEN=$$(echo "$$TOKEN_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha1',''))" 2>/dev/null); \
	[ -z "$$NEW_TOKEN" ] && echo "ERROR: Failed to create token: $$TOKEN_JSON" && exit 1; \
	echo "==> Updating gitea-credentials secret in sovereign-cloud..."; \
	oc create secret generic gitea-credentials -n sovereign-cloud \
	  --from-literal=GITEA_URL=http://gitea-http.gitea.svc:3000 \
	  --from-literal=GITEA_TOKEN=$$NEW_TOKEN \
	  --from-literal=REPO_OWNER=cloud \
	  --from-literal=REPO_NAME=git_resources \
	  --dry-run=client -o yaml | oc apply -f -; \
	oc rollout restart deployment/entity-operator -n sovereign-cloud 2>/dev/null || true; \
	echo "==> Gitea entity credentials configured"

deploy-custom-operators: install-custom-operators-git-creds install-custom-operators-pipelines ## Deploy git-creds + pipelines via ArgoCD Applications (OCI helm); see Phase 2 section

trigger-build-all: ## Trigger Tekton PipelineRuns to build all 8 custom operator images
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	$(MAKE) login; \
	echo "Creating PipelineRuns from $(CUSTOM_OPS_PIPELINES_CHART)/samples/pipelineruns/all-operators.yaml ..."; \
	oc create -f $(CUSTOM_OPS_PIPELINES_CHART)/samples/pipelineruns/all-operators.yaml -n sovereign-cloud 2>&1 && \
	  echo "All PipelineRuns created. Monitor with: oc get pipelinerun -n sovereign-cloud" || \
	  echo "Note: error above may be expected if runs already exist."

trigger-build: ## Trigger a PipelineRun for a single operator; requires OPERATOR=<name> REPO=<github-repo-name>
	@test -n "$${OPERATOR:-}" || { echo "Usage: make trigger-build OPERATOR=<name> REPO=<github-repo>"; exit 1; }; \
	REPO_NAME=$${REPO:-$$OPERATOR}; \
	TMPFILE=$$(mktemp /tmp/pipelinerun-XXXXXX.yaml); \
	printf 'apiVersion: tekton.dev/v1\nkind: PipelineRun\nmetadata:\n  generateName: %s-build-\n  labels:\n    operator: %s\nspec:\n  pipelineRef:\n    name: ansible-operator-image-build\n  params:\n  - name: git-url\n    value: https://github.com/hybrid-sovereign-cloud/%s.git\n  - name: image-name\n    value: %s\n  - name: image-tag\n    value: latest\n  workspaces:\n  - name: source\n    volumeClaimTemplate:\n      spec:\n        accessModes:\n        - ReadWriteOnce\n        resources:\n          requests:\n            storage: 1Gi\n  - name: git-credentials\n    secret:\n      secretName: github-basic-auth\n' \
	  "$$OPERATOR" "$$OPERATOR" "$$REPO_NAME" "$$OPERATOR" > "$$TMPFILE"; \
	oc create -n sovereign-cloud -f "$$TMPFILE" && \
	  echo "PipelineRun created. Monitor: oc get pipelinerun -n sovereign-cloud -l operator=$$OPERATOR"; \
	rm -f "$$TMPFILE"

wait-custom-operators: ## Wait for all custom operator pods to be ready
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	$(MAKE) login; \
	for dep in plugin-rbac entity-operator cloudaws-operator cloudoso-operator \
	           platformopenshift-operator team-operator projects-operator assignment-operator; do \
		echo -n "Waiting for $$dep ... "; \
		oc rollout status deployment/$$dep -n sovereign-cloud --timeout=300s 2>/dev/null || \
		oc rollout status deployment/$$dep -n sovereign-cloud-plugins --timeout=300s 2>/dev/null || \
		echo "  $$dep not found or not yet deployed"; \
	done

status-custom-operators: ## Show status of all custom operator deployments
	@echo "=== Custom Operator Pods (sovereign-cloud) ==="; \
	oc get pods -n sovereign-cloud 2>&1 | grep -E 'operator|pipeline' | grep -v 'build\|Completed' | head -15; \
	echo "=== Custom Operator Pods (sovereign-cloud-plugins) ==="; \
	oc get pods -n sovereign-cloud-plugins 2>&1 | grep -v 'docker\|Completed' | head -5; \
	echo "=== Custom Operator ArgoCD Apps ==="; \
	oc get applications.argoproj.io -n openshift-gitops 2>&1 | grep -E "plugin-rbac|entity-operator|cloudaws|cloudoso|platformopenshift|team-operator|projects-operator|assignment|custom-ops"; \
	echo "=== PipelineRuns ==="; \
	oc get pipelinerun -n sovereign-cloud 2>&1 | head -20; \
	echo "=== CRDs ==="; \
	oc get crd 2>&1 | grep -E "hybridsovereign|rbacplugins"; \
	echo "=== Sample CRs ==="; \
	oc get entity,rbacconfig 2>&1; \
	oc get rbac,container,cloudaws,team,assignment -n entity-acme 2>&1 | head -20

restart-custom-operators: ## Restart all custom operator deployments (pick up new images)
	@echo "==> Restarting custom operator deployments..."
	@for dep in assignment-operator cloudaws-operator cloudoso-operator entity-operator \
	            platformopenshift-operator team-operator projects-operator; do \
	  oc rollout restart deployment/$$dep -n sovereign-cloud 2>&1 | head -1; \
	done
	@oc rollout restart deployment/rbac-plugin-operator -n sovereign-cloud-plugins 2>&1 | head -1
	@echo "==> Waiting for rollouts to complete..."
	@for dep in assignment-operator cloudaws-operator cloudoso-operator entity-operator \
	            platformopenshift-operator team-operator projects-operator; do \
	  oc rollout status deployment/$$dep -n sovereign-cloud --timeout=120s 2>&1 | tail -1; \
	done
	@oc rollout status deployment/rbac-plugin-operator -n sovereign-cloud-plugins --timeout=60s 2>&1 | tail -1

sample-crs-apply: ## Apply sample Custom Resources for testing all 8 operators (ordered)
	@echo "==> Applying sample CRs in dependency order..."
	@SAMPLES=$(CHARTS_DIR)/instances/custom-operators-pipelines/samples; \
	oc apply -f $$SAMPLES/01-rbacconfig.yaml 2>&1; \
	echo "  Waiting for RbacConfig..."; sleep 5; \
	oc apply -f $$SAMPLES/02-entity.yaml 2>&1; \
	echo "  Waiting for Entity namespace..."; sleep 15; \
	oc apply -f $$SAMPLES/03-rbac.yaml 2>&1; \
	oc apply -f $$SAMPLES/04-cloudaws-container.yaml 2>&1; \
	oc apply -f $$SAMPLES/05-team-container.yaml 2>&1; \
	oc apply -f $$SAMPLES/07-cloudoso-container.yaml 2>&1; \
	sleep 10; \
	oc apply -f $$SAMPLES/06-assignment.yaml 2>&1; \
	oc apply -f $$SAMPLES/08-platformopenshift-sample.yaml 2>&1; \
	oc apply -f $$SAMPLES/09-projects-sample.yaml 2>&1; \
	echo "==> Sample CRs applied. Checking status..."; \
	sleep 15; \
	echo "--- RbacConfig ---"; oc get rbacconfig -n sovereign-cloud 2>&1; \
	echo "--- Entity ---"; oc get entity 2>&1; \
	echo "--- Rbac ---"; oc get rbac -n entity-acme 2>&1; \
	echo "--- CloudAWS Containers ---"; oc get container -n entity-acme 2>&1; \
	echo "--- CloudOSO ---"; oc get cloudosos.hybridsovereign.redhat -A 2>&1; \
	echo "--- PlatformOpenshift ---"; oc get platformopenshifts.hybridsovereign.redhat -A 2>&1; \
	echo "--- Projects ---"; oc get projects.hybridsovereign.redhat -A 2>&1; \
	echo "--- Teams ---"; oc get teams.hybridsovereign.redhat -A 2>&1; \
	echo "--- Assignment ---"; oc get assignment.hybridsovereign.redhat -A 2>&1

##@ Status
status: ## Show status of all helm releases and key resources
	@echo "=== Helm Releases ==="; helm list -A 2>&1
	@echo "=== Argo CD Applications ==="; oc get application.argoproj.io -n openshift-gitops 2>&1 | head -40
	@echo "=== Operator CSVs ==="; oc get csv -A 2>&1 | grep -E "(Succeeded|Failed|Installing|Pending)" | head -30
	@echo "=== Key Pods ==="; oc get pods -n vault 2>&1; oc get pods -n rhbk 2>&1
	@echo "=== RHACM Status ==="; oc get multiclusterhub -n open-cluster-management 2>&1 | head -5
	@echo "=== RHACS Status ==="; oc get central -n stackrox 2>&1 | head -5
	@echo "=== Custom Operators ==="; oc get pods -n sovereign-cloud --field-selector=status.phase=Running 2>&1 | head -20

##@ Phase 4 / 5: Testing
apply-phase4-samples: ## Apply Phase4 Entity beta + all container types sample CRs
	@echo "==> Creating Entity beta..."
	@oc apply -f $(CUSTOM_OPS_PIPELINES_CHART)/samples/02-entity-beta.yaml 2>&1 | head -3
	@echo "==> Waiting for entity-beta namespace (up to 3m)..."
	@for i in $$(seq 1 18); do \
	  oc get namespace entity-beta 2>/dev/null && break; \
	  echo "  [$$i/18] entity-beta not yet created..."; sleep 10; \
	done
	@echo "==> Applying all container types for beta + fixing ocp1..."
	@oc apply -f $(CUSTOM_OPS_PIPELINES_CHART)/samples/phase4-beta-entity-all-containers.yaml 2>&1 | grep -E "created|configured|unchanged|Error" | head -20
	@echo "==> Phase 4 CRs applied. Check with: make status-phase4"

status-phase4: ## Show status of Phase4 entities, containers, and Keycloak groups
	@echo "=== Entities ==="; oc get entity 2>&1
	@echo "=== Containers (entity-acme) ==="; oc get container -n entity-acme 2>&1
	@echo "=== Containers (entity-beta) ==="; oc get container -n entity-beta 2>&1
	@echo "=== Rbac CRs (entity-beta) ==="; oc get rbac -n entity-beta 2>&1
	@echo "=== CloudAWS ==="; oc get cloudaws -A 2>&1
	@echo "=== CloudOSO ==="; oc get cloudoso -A 2>&1
	@echo "=== PlatformOpenshifts ==="; oc get platformopenshifts -A 2>&1
	@echo "=== Teams ==="; oc get teams -A 2>&1
	@echo "=== Projects (CRD) ==="; oc get projects.hybridsovereign.redhat -A 2>&1
	@echo "=== Assignments ==="; oc get assignments.hybridsovereign.redhat -A 2>&1
	@echo "=== Keycloak Groups ==="; \
	  KC_URL=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_URL}' 2>/dev/null | base64 -d); \
	  KC_REALM=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_REALM}' 2>/dev/null | base64 -d); \
	  KC_AUTH_REALM=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_AUTH_REALM}' 2>/dev/null | base64 -d); \
	  KC_USER=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_USERNAME}' 2>/dev/null | base64 -d); \
	  KC_PASS=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_PASSWORD}' 2>/dev/null | base64 -d); \
	  TOKEN=$$(curl -sk -X POST "$$KC_URL/realms/$${KC_AUTH_REALM:-master}/protocol/openid-connect/token" \
	    -d "grant_type=password&client_id=admin-cli&username=$$KC_USER&password=$$KC_PASS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null); \
	  if [ -n "$$TOKEN" ]; then \
	    curl -sk -H "Authorization: Bearer $$TOKEN" "$$KC_URL/admin/realms/$$KC_REALM/groups" | python3 -c "import sys,json; [print(g.get('name',''), g.get('path',''), g.get('subGroups',[])) for g in json.load(sys.stdin)]" 2>/dev/null; \
	  else echo "Cannot get Keycloak token"; fi

create-devuser: ## Create devuser in Keycloak sovereign-tenants realm, add to beta/admins group (Phase 5)
	@echo "==> Creating devuser in Keycloak sovereign-tenants realm..."
	@KC_URL=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_URL}' 2>/dev/null | base64 -d); \
	KC_REALM=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_REALM}' 2>/dev/null | base64 -d); \
	KC_AUTH_REALM=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_AUTH_REALM}' 2>/dev/null | base64 -d); \
	KC_USER=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_USERNAME}' 2>/dev/null | base64 -d); \
	KC_PASS=$$(oc get secret keycloak-auth-config -n sovereign-cloud -o jsonpath='{.data.KC_PASSWORD}' 2>/dev/null | base64 -d); \
	TOKEN=$$(curl -sk -X POST "$$KC_URL/realms/$${KC_AUTH_REALM:-master}/protocol/openid-connect/token" \
	  -d "grant_type=password&client_id=admin-cli&username=$$KC_USER&password=$$KC_PASS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))"); \
	if [ -z "$$TOKEN" ]; then echo "Cannot get Keycloak token"; exit 1; fi; \
	echo "==> Token OK. Realm: $$KC_REALM"; \
	USER_ID=$$(curl -sk -H "Authorization: Bearer $$TOKEN" \
	  "$$KC_URL/admin/realms/$$KC_REALM/users?search=devuser" | \
	  python3 -c "import sys,json; u=json.load(sys.stdin); print(u[0]['id'] if u else '')"); \
	if [ -z "$$USER_ID" ]; then \
	  HTTP=$$(curl -sk -o /dev/null -w "%{http_code}" -X POST \
	    -H "Authorization: Bearer $$TOKEN" -H "Content-Type: application/json" \
	    "$$KC_URL/admin/realms/$$KC_REALM/users" \
	    -d '{"username":"devuser","email":"devuser@sovereign.local","enabled":true,"credentials":[{"type":"password","value":"devpassword1!","temporary":false}]}'); \
	  echo "Create devuser: HTTP $$HTTP"; \
	  USER_ID=$$(curl -sk -H "Authorization: Bearer $$TOKEN" \
	    "$$KC_URL/admin/realms/$$KC_REALM/users?search=devuser" | \
	    python3 -c "import sys,json; u=json.load(sys.stdin); print(u[0]['id'] if u else '')"); \
	else echo "User devuser already exists: $$USER_ID"; fi; \
	echo "User ID: $$USER_ID"; \
	BETA_ID=$$(curl -sk -H "Authorization: Bearer $$TOKEN" \
	  "$$KC_URL/admin/realms/$$KC_REALM/groups" | \
	  python3 -c "import sys,json; gs=json.load(sys.stdin); [print(g['id']) for g in gs if g.get('name')=='beta']"); \
	ADMINS_ID=$$(curl -sk -H "Authorization: Bearer $$TOKEN" \
	  "$$KC_URL/admin/realms/$$KC_REALM/groups/$$BETA_ID/children" | \
	  python3 -c "import sys,json; gs=json.load(sys.stdin); [print(g['id']) for g in gs if g.get('name')=='admins']"); \
	echo "beta/admins group: $$ADMINS_ID"; \
	if [ -n "$$ADMINS_ID" ] && [ -n "$$USER_ID" ]; then \
	  STATUS=$$(curl -sk -o /dev/null -w "%{http_code}" -X PUT \
	    -H "Authorization: Bearer $$TOKEN" \
	    "$$KC_URL/admin/realms/$$KC_REALM/users/$$USER_ID/groups/$$ADMINS_ID"); \
	  echo "Add devuser to beta/admins: HTTP $$STATUS"; \
	else echo "ERROR: beta/admins group or devuser not found."; fi

##@ ACS Fixes
debug-acs-consoleplugin: ## Read-only: show Console cluster plugins + advanced-cluster-security ConsolePlugin backend (oc get only)
	@echo "=== consoles.operator.openshift.io cluster spec.plugins ==="
	@oc get consoles.operator.openshift.io cluster -o jsonpath='{.spec.plugins}' 2>/dev/null; echo ""
	@echo "=== consoleplugin advanced-cluster-security (backend) ==="
	@oc get consoleplugin advanced-cluster-security -o yaml 2>/dev/null | sed -n '1,80p' || echo "(not found)"

regenerate-acs-init-bundle: ## Regenerate ACS init bundle (sensor-tls/collector-tls/admission-control-tls) from Central API
	@echo "==> Regenerating ACS init bundle..."
	@CENTRAL_HOST=$$(oc get route central -n stackrox -o jsonpath='{.spec.host}' 2>/dev/null); \
	ADMIN_PASS=$$(oc get secret central-htpasswd -n stackrox -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
	CENTRAL_URL="https://$${CENTRAL_HOST}"; \
	echo "Central: $${CENTRAL_URL}"; \
	oc get secret tls-cert-admission-control -n stackrox &>/dev/null && \
	  { echo "Init bundle secrets exist. Delete sensor-tls/collector-tls/admission-control-tls first to regenerate."; exit 0; }; \
	BUNDLE_RESP=$$(curl -sk -u "admin:$${ADMIN_PASS}" \
	  -X POST "$${CENTRAL_URL}/v1/cluster-init/init-bundles" \
	  -H "Content-Type: application/json" \
	  -d '{"name":"local-cluster-bundle"}'); \
	BUNDLE_B64=$$(echo "$$BUNDLE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('kubectlBundle',''))"); \
	printf '%s' "$$BUNDLE_B64" | base64 -d | oc apply -n stackrox -f -; \
	echo "==> Init bundle secrets applied. Restarting sensor and admission-control..."; \
	oc rollout restart deployment/sensor deployment/admission-control -n stackrox

fix-acs-consoleplugin: ## Fix ACS consoleplugin backend to use central:443 (align with rhacs-config PostSync job)
	@echo "==> Patching ACS consoleplugin -> central:443 /static/ocp-plugin in stackrox..."
	@NS=stackrox; \
	CURRENT=$$(oc get consoleplugin advanced-cluster-security \
	  -o jsonpath='{.spec.backend.service.name}' 2>/dev/null || echo ""); \
	PORT=$$(oc get consoleplugin advanced-cluster-security \
	  -o jsonpath='{.spec.backend.service.port}' 2>/dev/null || echo ""); \
	BP=$$(oc get consoleplugin advanced-cluster-security \
	  -o jsonpath='{.spec.backend.service.basePath}' 2>/dev/null || echo ""); \
	if [ "$$CURRENT" = "central" ] && [ "$$PORT" = "443" ] && [ "$$BP" = "/static/ocp-plugin" ]; then \
	  echo "Already patched. Nothing to do."; \
	else \
	  oc patch consoleplugin advanced-cluster-security --type=merge \
	    -p "{\"spec\":{\"backend\":{\"type\":\"Service\",\"service\":{\"name\":\"central\",\"namespace\":\"$$NS\",\"port\":443,\"basePath\":\"/static/ocp-plugin\"}}}}"; \
	  echo "Patched."; \
	fi

# ===========================================================================
##@ OCI Registry (Phase 1) — Package and push all Helm charts to quay.io
# ===========================================================================

oci-login: ## Login to OCI Helm registry (uses OCI_REGISTRY_TOKEN from ~/.bashrc)
	@$(SOURCE_BASHRC); \
	test -n "$${OCI_REGISTRY_TOKEN:-}" || { echo "ERROR: OCI_REGISTRY_TOKEN not set in ~/.bashrc"; exit 1; }; \
	echo "==> Logging in to $(OCI_REGISTRY_HOST)..."; \
	helm registry login $(OCI_REGISTRY_HOST) \
		--username '$$oauthtoken' \
		--password "$${OCI_REGISTRY_TOKEN}"; \
	echo "==> Login successful"

oci-push-bootstrap: oci-login ## Package and push all bootstrap charts to OCI registry (pre-creates repos as public)
	@$(SOURCE_BASHRC); \
	mkdir -p /tmp/helm-oci-push; \
	echo "==> Pushing all bootstrap charts to $(OCI_HELM_REGISTRY)"; \
	for chart in $$(find $(CHARTS_DIR) -name Chart.yaml -exec dirname {} \; | sort -u); do \
		name=$$(grep '^name:' "$$chart/Chart.yaml" | awk '{print $$2}'); \
		version=$$(grep '^version:' "$$chart/Chart.yaml" | awk '{print $$2}'); \
		echo "--- Pre-creating public repo for $$name"; \
		curl -sk -X POST "https://quay.io/api/v1/repository" \
			-H "Authorization: Bearer $${OCI_REGISTRY_TOKEN}" \
			-H "Content-Type: application/json" \
			-d "{\"repository\":\"$${name}\",\"namespace\":\"$(OCI_ORG)\",\"description\":\"Helm chart: $${name}\",\"visibility\":\"public\",\"repo_kind\":\"image\"}" \
			> /dev/null 2>&1 || true; \
		echo "--- Packaging $$name v$$version from $$chart"; \
		if grep -q '^dependencies:' "$$chart/Chart.yaml" 2>/dev/null; then \
			helm dependency update "$$chart" 2>/dev/null || true; \
		fi; \
		helm package "$$chart" -d /tmp/helm-oci-push/ --version "$$version" 2>&1 | tail -1; \
		echo "--- Pushing $$name:$$version"; \
		helm push "/tmp/helm-oci-push/$${name}-$${version}.tgz" $(OCI_HELM_REGISTRY) 2>&1 | tail -2; \
	done; \
	echo "==> All bootstrap charts pushed to $(OCI_HELM_REGISTRY)"

oci-push-operators: oci-login ## Package and push all operator repo charts to OCI registry (pre-creates repos as public)
	@$(SOURCE_BASHRC); \
	mkdir -p /tmp/helm-oci-push; \
	OPERATOR_REPOS="Assignment CloudAWS CloudOSO PlatformOpenshift plugin_rbac Projects sovereign_tenancy Team console"; \
	WORKSPACE=$$(dirname $$(pwd)); \
	echo "==> Pushing operator charts from: $$OPERATOR_REPOS"; \
	for repo in $$OPERATOR_REPOS; do \
		REPO_DIR="$$WORKSPACE/$$repo"; \
		[ -d "$$REPO_DIR/helm" ] || { echo "SKIP $$repo: no helm/ dir"; continue; }; \
		for chart in $$(find "$$REPO_DIR/helm" -name Chart.yaml -exec dirname {} \; | sort -u); do \
			name=$$(grep '^name:' "$$chart/Chart.yaml" | awk '{print $$2}'); \
			version=$$(grep '^version:' "$$chart/Chart.yaml" | awk '{print $$2}'); \
			echo "--- Pre-creating public repo for $$name"; \
			curl -sk -X POST "https://quay.io/api/v1/repository" \
				-H "Authorization: Bearer $${OCI_REGISTRY_TOKEN}" \
				-H "Content-Type: application/json" \
				-d "{\"repository\":\"$${name}\",\"namespace\":\"$(OCI_ORG)\",\"description\":\"Helm chart: $${name}\",\"visibility\":\"public\",\"repo_kind\":\"image\"}" \
				> /dev/null 2>&1 || true; \
			echo "--- Packaging $$name v$$version from $$chart"; \
			if grep -q '^dependencies:' "$$chart/Chart.yaml" 2>/dev/null; then \
				helm dependency update "$$chart" 2>/dev/null || true; \
			fi; \
			helm package "$$chart" -d /tmp/helm-oci-push/ --version "$$version" 2>&1 | tail -1; \
			echo "--- Pushing $$name:$$version"; \
			helm push "/tmp/helm-oci-push/$${name}-$${version}.tgz" $(OCI_HELM_REGISTRY) 2>&1 | tail -2; \
		done; \
	done; \
	echo "==> All operator charts pushed to $(OCI_HELM_REGISTRY)"

oci-push-all: oci-push-bootstrap oci-push-operators ## Push ALL charts (bootstrap + all operator repos) to OCI registry
	@echo "==> All charts pushed to $(OCI_HELM_REGISTRY)"

oci-make-public: ## Ensure all known charts are public in Quay (idempotent)
	@$(SOURCE_BASHRC); \
	test -n "$${OCI_REGISTRY_TOKEN:-}" || { echo "ERROR: OCI_REGISTRY_TOKEN not set"; exit 1; }; \
	for name in \
		aap-operator external-secrets-operator gitops-operator odf-operator \
		openshift-pipelines-operator quay-operator rhacm-operator rhacs-operator rhbk-operator \
		aap-instance custom-operators-git-creds custom-operators-pipelines gitea-instance \
		gitops-instance odf-noobaa pipelines-bootstrap quay-instance rhacm-instance \
		rhacs-instance rhbk-instance sovereign-cloud vault-instance \
		argocd-init-job custom-operators-applicationset platform-applicationset \
		dynamic-plugins-config external-secrets-config keycloak-config rhacm-config \
		rhacs-config service-oidc-config vault-init \
		assignment-operator assignment-operator-imagestreams assignment-operator-samples \
		cloudaws-operator cloudaws-operator-imagestreams cloudaws-operator-samples \
		cloudoso-operator cloudoso-operator-imagestreams cloudoso-operator-samples \
		platformopenshift-operator platformopenshift-operator-imagestreams platformopenshift-operator-samples \
		rbac-plugin-operator rbac-plugin-imagestream \
		projects-operator projects-operator-imagestreams projects-operator-samples \
		entity-operator entity-operator-imagestreams entity-operator-samples \
		team-operator team-operator-imagestreams team-operator-samples \
		sovereign-cloud-plugin sovereign-cloud-image; do \
		STATUS=$$(curl -sk -o /dev/null -w "%{http_code}" -X POST \
			"https://quay.io/api/v1/repository/$(OCI_ORG)/$${name}/changevisibility" \
			-H "Authorization: Bearer $${OCI_REGISTRY_TOKEN}" \
			-H "Content-Type: application/json" \
			-d '{"visibility":"public"}'); \
		echo "  $$name → HTTP $$STATUS"; \
	done

# ===========================================================================
##@ GitOps Applications (Phase 2) — ArgoCD Applications using OCI Helm charts
# All install-* targets deploy an ArgoCD Application pointing to the OCI chart.
# All uninstall-* targets delete the Application (and prune its resources).
# ===========================================================================

# Internal helper — wait for an ArgoCD Application to become Synced+Healthy
wait-argoapp: ## Wait for ArgoCD Application APP= to become Synced+Healthy (up to 10m)
	@test -n "$(APP)" || { echo "Usage: make wait-argoapp APP=<name>"; exit 1; }; \
	echo "==> Waiting for Application $(APP) Synced+Healthy (up to 10m)..."; \
	for i in $$(seq 1 60); do \
	  SYNC=$$(oc get application.argoproj.io "$(APP)" -n openshift-gitops \
	    -o jsonpath='{.status.sync.status}' 2>/dev/null || echo ""); \
	  HEALTH=$$(oc get application.argoproj.io "$(APP)" -n openshift-gitops \
	    -o jsonpath='{.status.health.status}' 2>/dev/null || echo ""); \
	  echo "  [$$i/60] $(APP): sync=$$SYNC health=$$HEALTH"; \
	  [ "$$SYNC" = "Synced" ] && [ "$$HEALTH" = "Healthy" ] && \
	    { echo "==> $(APP): Synced+Healthy"; exit 0; }; \
	  sleep 10; \
	done; \
	echo "WARNING: $(APP) did not reach Synced+Healthy in 10m"

sync-wait-argoapp: ## Force sync APP= and wait for Synced+Healthy
	@test -n "$(APP)" || { echo "Usage: make sync-wait-argoapp APP=<name>"; exit 1; }; \
	$(MAKE) sync-argocd-app APP=$(APP); \
	$(MAKE) wait-argoapp APP=$(APP)

teardown-all-argocd-apps: ## Delete ALL sovereign ArgoCD Applications (preserves gitops operator)
	@echo "==> Deleting all sovereign ArgoCD Applications..."; \
	oc get application.argoproj.io -n openshift-gitops \
	  -l app.kubernetes.io/managed-by=sovereign-bootstrap \
	  -o name 2>/dev/null | xargs -r oc delete -n openshift-gitops --ignore-not-found; \
	echo "==> Done"

##@ Operators (Phase 2 — ArgoCD Application + OCI Helm)

install-aap-operator: ## Deploy AAP operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh aap-operator aap-operator ansible-automation-platform 10; \
	$(MAKE) sync-wait-argoapp APP=aap-operator

uninstall-aap-operator: ## Delete AAP operator ArgoCD Application (prunes OLM resources)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io aap-operator -n openshift-gitops --ignore-not-found; \
	echo "==> aap-operator Application deleted"

install-eso-operator: ## Deploy External Secrets operator via ArgoCD Application (OCI helm v0.1.1)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.1 bash $(SCRIPTS_DIR)/apply-argoapp.sh eso-operator external-secrets-operator external-secrets-operator 20; \
	$(MAKE) sync-wait-argoapp APP=eso-operator

uninstall-eso-operator: ## Delete External Secrets operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io eso-operator -n openshift-gitops --ignore-not-found; \
	echo "==> eso-operator Application deleted"

install-odf-operator: ## Deploy ODF operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh odf-operator odf-operator openshift-storage 30; \
	$(MAKE) sync-wait-argoapp APP=odf-operator

uninstall-odf-operator: ## Delete ODF operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io odf-operator -n openshift-gitops --ignore-not-found; \
	echo "==> odf-operator Application deleted"

install-openshift-pipelines-operator: ## Deploy OpenShift Pipelines operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh openshift-pipelines-operator openshift-pipelines-operator openshift-operators 40; \
	$(MAKE) sync-wait-argoapp APP=openshift-pipelines-operator

uninstall-openshift-pipelines-operator: ## Delete OpenShift Pipelines operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io openshift-pipelines-operator -n openshift-gitops --ignore-not-found; \
	echo "==> openshift-pipelines-operator Application deleted"

install-quay-operator: ## Deploy Quay operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh quay-operator quay-operator quay 50; \
	$(MAKE) sync-wait-argoapp APP=quay-operator

uninstall-quay-operator: ## Delete Quay operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io quay-operator -n openshift-gitops --ignore-not-found; \
	echo "==> quay-operator Application deleted"

install-rhbk-operator: ## Deploy RHBK operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhbk-operator rhbk-operator rhbk 60; \
	$(MAKE) sync-wait-argoapp APP=rhbk-operator

uninstall-rhbk-operator: ## Delete RHBK operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhbk-operator -n openshift-gitops --ignore-not-found; \
	echo "==> rhbk-operator Application deleted"

install-rhacm-operator: ## Deploy RHACM operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhacm-operator rhacm-operator open-cluster-management 65; \
	$(MAKE) sync-wait-argoapp APP=rhacm-operator

uninstall-rhacm-operator: ## Delete RHACM operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhacm-operator -n openshift-gitops --ignore-not-found; \
	echo "==> rhacm-operator Application deleted"

install-rhacs-operator: ## Deploy RHACS operator via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhacs-operator rhacs-operator rhacs-operator 70; \
	$(MAKE) sync-wait-argoapp APP=rhacs-operator

uninstall-rhacs-operator: ## Delete RHACS operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhacs-operator -n openshift-gitops --ignore-not-found; \
	echo "==> rhacs-operator Application deleted"

install-all-operators: ## Deploy all core operators via ArgoCD Applications (OCI helm)
	@$(MAKE) install-aap-operator
	@$(MAKE) install-eso-operator
	@$(MAKE) install-rhbk-operator
	@$(MAKE) install-quay-operator
	@$(MAKE) install-openshift-pipelines-operator

install-all-operators-with-storage: install-all-operators install-odf-operator ## All operators plus ODF

##@ Instances (Phase 2 — ArgoCD Application + OCI Helm)

install-sovereign-cloud: ## Deploy sovereign-cloud namespace/config via ArgoCD Application (OCI helm v0.1.1)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.1 bash $(SCRIPTS_DIR)/apply-argoapp.sh sovereign-cloud sovereign-cloud sovereign-cloud 100; \
	$(MAKE) sync-wait-argoapp APP=sovereign-cloud

uninstall-sovereign-cloud: ## Delete sovereign-cloud ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io sovereign-cloud -n openshift-gitops --ignore-not-found; \
	echo "==> sovereign-cloud Application deleted"

install-vault-instance: ## Deploy Vault instance via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh vault-instance vault-instance vault 110; \
	$(MAKE) sync-wait-argoapp APP=vault-instance

uninstall-vault-instance: ## Delete Vault instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io vault-instance -n openshift-gitops --ignore-not-found; \
	echo "==> vault-instance Application deleted"

install-rhbk-instance: ## Deploy RHBK/Keycloak instance via ArgoCD Application (OCI helm, sets hostname)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhbk-instance rhbk-instance rhbk 120 \
		"hostname=keycloak-rhbk.$$APPS_DOMAIN"; \
	$(MAKE) sync-wait-argoapp APP=rhbk-instance

uninstall-rhbk-instance: ## Delete RHBK instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhbk-instance -n openshift-gitops --ignore-not-found; \
	echo "==> rhbk-instance Application deleted"

install-gitea-instance: ## Deploy Gitea instance via ArgoCD Application (OCI helm, sets domain/route)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh gitea-instance gitea-instance gitea 125 \
		"gitea.gitea.config.server.DOMAIN=gitea.$$APPS_DOMAIN" \
		"gitea.gitea.config.server.ROOT_URL=https://gitea.$$APPS_DOMAIN" \
		"gitea.route.enabled=true" \
		"gitea.route.host=gitea.$$APPS_DOMAIN" \
		"gitea.route.tls.termination=edge"; \
	$(MAKE) sync-wait-argoapp APP=gitea-instance

uninstall-gitea-instance: ## Delete Gitea instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io gitea-instance -n openshift-gitops --ignore-not-found; \
	echo "==> gitea-instance Application deleted"

install-odf-noobaa: ## Deploy ODF NooBaa instance via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.1 bash $(SCRIPTS_DIR)/apply-argoapp.sh odf-noobaa odf-noobaa openshift-storage 130; \
	$(MAKE) sync-wait-argoapp APP=odf-noobaa

uninstall-odf-noobaa: ## Delete ODF NooBaa ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io odf-noobaa -n openshift-gitops --ignore-not-found; \
	echo "==> odf-noobaa Application deleted"

install-pipelines-bootstrap: ## Deploy Pipelines bootstrap (ImageStreams + Pipeline) via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh pipelines-bootstrap pipelines-bootstrap sovereign-cloud 135; \
	$(MAKE) sync-wait-argoapp APP=pipelines-bootstrap

uninstall-pipelines-bootstrap: ## Delete pipelines-bootstrap ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io pipelines-bootstrap -n openshift-gitops --ignore-not-found; \
	echo "==> pipelines-bootstrap Application deleted"

install-quay-instance: ## Deploy Quay registry instance via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.2 bash $(SCRIPTS_DIR)/apply-argoapp.sh quay-instance quay-instance quay 140; \
	$(MAKE) sync-wait-argoapp APP=quay-instance

uninstall-quay-instance: ## Delete Quay instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io quay-instance -n openshift-gitops --ignore-not-found; \
	echo "==> quay-instance Application deleted"

install-rhacm-instance: ## Deploy RHACM MultiClusterHub via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhacm-instance rhacm-instance open-cluster-management 150; \
	$(MAKE) sync-wait-argoapp APP=rhacm-instance

uninstall-rhacm-instance: ## Delete RHACM instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhacm-instance -n openshift-gitops --ignore-not-found; \
	echo "==> rhacm-instance Application deleted"

install-rhacs-instance: ## Deploy RHACS Central+SecuredCluster via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhacs-instance rhacs-instance stackrox 155; \
	$(MAKE) sync-wait-argoapp APP=rhacs-instance

uninstall-rhacs-instance: ## Delete RHACS instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhacs-instance -n openshift-gitops --ignore-not-found; \
	echo "==> rhacs-instance Application deleted"

install-all-instances: ## Deploy all core instances via ArgoCD Applications (OCI helm)
	@$(MAKE) install-sovereign-cloud
	@$(MAKE) install-aap-instance
	@$(MAKE) install-vault-instance
	@$(MAKE) install-rhbk-instance

##@ Config (Phase 2 — ArgoCD Application + OCI Helm)

install-vault-init: ## Deploy vault-init config job via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh vault-init vault-init vault 200; \
	$(MAKE) sync-wait-argoapp APP=vault-init

uninstall-vault-init: ## Delete vault-init ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io vault-init -n openshift-gitops --ignore-not-found; \
	echo "==> vault-init Application deleted"

install-keycloak-config: ## Deploy keycloak-config job via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	CHART_VERSION=0.1.1 bash $(SCRIPTS_DIR)/apply-argoapp.sh keycloak-config keycloak-config rhbk 210 \
		"keycloakUrl=https://keycloak-rhbk.$$APPS_DOMAIN"; \
	$(MAKE) sync-wait-argoapp APP=keycloak-config

uninstall-keycloak-config: ## Delete keycloak-config ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io keycloak-config -n openshift-gitops --ignore-not-found; \
	echo "==> keycloak-config Application deleted"

install-external-secrets-config: ## Deploy external-secrets-config via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh external-secrets-config external-secrets-config sovereign-cloud 220; \
	$(MAKE) sync-wait-argoapp APP=external-secrets-config

uninstall-external-secrets-config: ## Delete external-secrets-config ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io external-secrets-config -n openshift-gitops --ignore-not-found; \
	echo "==> external-secrets-config Application deleted"

install-service-oidc-config: ## Deploy service-oidc-config via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh service-oidc-config service-oidc-config sovereign-cloud 230 \
		"keycloakUrl=https://keycloak-rhbk.$$APPS_DOMAIN"; \
	$(MAKE) sync-wait-argoapp APP=service-oidc-config

uninstall-service-oidc-config: ## Delete service-oidc-config ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io service-oidc-config -n openshift-gitops --ignore-not-found; \
	echo "==> service-oidc-config Application deleted"

install-rhacs-config: ## Deploy rhacs-config job via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhacs-config rhacs-config stackrox 240 \
		"keycloakUrl=https://keycloak-rhbk.$$APPS_DOMAIN"; \
	$(MAKE) sync-wait-argoapp APP=rhacs-config

uninstall-rhacs-config: ## Delete rhacs-config ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhacs-config -n openshift-gitops --ignore-not-found; \
	echo "==> rhacs-config Application deleted"

install-rhacm-config: ## Deploy rhacm-config job via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh rhacm-config rhacm-config open-cluster-management 245; \
	$(MAKE) sync-wait-argoapp APP=rhacm-config

uninstall-rhacm-config: ## Delete rhacm-config ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io rhacm-config -n openshift-gitops --ignore-not-found; \
	echo "==> rhacm-config Application deleted"

install-dynamic-plugins-config: ## Deploy dynamic-plugins-config via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.1 bash $(SCRIPTS_DIR)/apply-argoapp.sh dynamic-plugins-config dynamic-plugins-config sovereign-cloud 290; \
	$(MAKE) sync-wait-argoapp APP=dynamic-plugins-config

uninstall-dynamic-plugins-config: ## Delete dynamic-plugins-config ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io dynamic-plugins-config -n openshift-gitops --ignore-not-found; \
	echo "==> dynamic-plugins-config Application deleted"

##@ Custom Operators GitOps (Phase 2 — ArgoCD Application + OCI Helm)

install-custom-operators-git-creds: ## Deploy custom-operators-git-creds via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	test -n "$${GITHUB_TOKEN:-}" || { echo "GITHUB_TOKEN is required."; exit 1; }; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh custom-operators-git-creds custom-operators-git-creds openshift-gitops 275 \
		"githubToken=$${GITHUB_TOKEN}"; \
	$(MAKE) sync-wait-argoapp APP=custom-operators-git-creds

uninstall-custom-operators-git-creds: ## Delete custom-operators-git-creds ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io custom-operators-git-creds -n openshift-gitops --ignore-not-found; \
	echo "==> custom-operators-git-creds Application deleted"

install-custom-operators-pipelines: ## Deploy custom-operators-pipelines via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.2 bash $(SCRIPTS_DIR)/apply-argoapp.sh custom-operators-pipelines custom-operators-pipelines sovereign-cloud 280; \
	$(MAKE) sync-wait-argoapp APP=custom-operators-pipelines

uninstall-custom-operators-pipelines: ## Delete custom-operators-pipelines ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io custom-operators-pipelines -n openshift-gitops --ignore-not-found; \
	echo "==> custom-operators-pipelines Application deleted"

install-custom-operators-applicationset: ## DEPRECATED: replaced by per-operator Application targets
	@echo "NOTICE: install-custom-operators-applicationset is replaced by per-operator install targets."; \
	echo "Use: make install-plugin-rbac install-entity-operator install-cloudaws-operator ..."; \
	echo "or:  make deploy-custom-operators"

uninstall-custom-operators-applicationset: ## Delete the legacy custom-operators ApplicationSet if present
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete applicationset.argoproj.io custom-operators-appset -n openshift-gitops --ignore-not-found; \
	echo "==> custom-operators-appset ApplicationSet deleted (if present)"

deploy-custom-operators: install-custom-operators-git-creds install-custom-operators-pipelines ## Deploy git-creds + pipelines (triggers builds; then install per-operator)
	@echo "==> Custom operator prerequisites deployed."
	@echo "==> Trigger builds with: make trigger-build-all"
	@echo "==> After builds complete, deploy operators with: make install-plugin-rbac install-entity-operator ..."

##@ Custom Operator Deployments (Phase 2 — ArgoCD Application + OCI Helm from operator repos)

install-plugin-rbac: ## Deploy plugin-rbac operator via ArgoCD Application (OCI helm v0.2.1)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.2.2 bash $(SCRIPTS_DIR)/apply-argoapp.sh plugin-rbac rbac-plugin-operator sovereign-cloud-plugins 300; \
	$(MAKE) sync-wait-argoapp APP=plugin-rbac

uninstall-plugin-rbac: ## Delete plugin-rbac ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io plugin-rbac -n openshift-gitops --ignore-not-found; \
	echo "==> plugin-rbac Application deleted"

install-entity-operator: ## Deploy entity-operator via ArgoCD Application (OCI helm v0.1.1)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.3 bash $(SCRIPTS_DIR)/apply-argoapp.sh entity-operator entity-operator sovereign-cloud 310; \
	$(MAKE) sync-wait-argoapp APP=entity-operator

uninstall-entity-operator: ## Delete entity-operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io entity-operator -n openshift-gitops --ignore-not-found; \
	echo "==> entity-operator Application deleted"

install-cloudaws-operator: ## Deploy CloudAWS operator via ArgoCD Application (OCI helm v0.1.3)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.3 bash $(SCRIPTS_DIR)/apply-argoapp.sh cloudaws-operator cloudaws-operator sovereign-cloud 320; \
	$(MAKE) sync-wait-argoapp APP=cloudaws-operator

uninstall-cloudaws-operator: ## Delete CloudAWS operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io cloudaws-operator -n openshift-gitops --ignore-not-found; \
	echo "==> cloudaws-operator Application deleted"

install-cloudoso-operator: ## Deploy CloudOSO operator via ArgoCD Application (OCI helm v0.1.3)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.3 bash $(SCRIPTS_DIR)/apply-argoapp.sh cloudoso-operator cloudoso-operator sovereign-cloud 320; \
	$(MAKE) sync-wait-argoapp APP=cloudoso-operator

uninstall-cloudoso-operator: ## Delete CloudOSO operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io cloudoso-operator -n openshift-gitops --ignore-not-found; \
	echo "==> cloudoso-operator Application deleted"

install-platformopenshift-operator: ## Deploy PlatformOpenshift operator via ArgoCD Application (OCI helm v0.1.2)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.2 bash $(SCRIPTS_DIR)/apply-argoapp.sh platformopenshift-operator platformopenshift-operator sovereign-cloud 330; \
	$(MAKE) sync-wait-argoapp APP=platformopenshift-operator

uninstall-platformopenshift-operator: ## Delete PlatformOpenshift operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io platformopenshift-operator -n openshift-gitops --ignore-not-found; \
	echo "==> platformopenshift-operator Application deleted"

install-team-operator: ## Deploy Team operator via ArgoCD Application (OCI helm v0.1.2)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.2 bash $(SCRIPTS_DIR)/apply-argoapp.sh team-operator team-operator sovereign-cloud 330; \
	$(MAKE) sync-wait-argoapp APP=team-operator

uninstall-team-operator: ## Delete Team operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io team-operator -n openshift-gitops --ignore-not-found; \
	echo "==> team-operator Application deleted"

install-projects-operator: ## Deploy Projects operator via ArgoCD Application (OCI helm v0.1.1)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.1 bash $(SCRIPTS_DIR)/apply-argoapp.sh projects-operator projects-operator sovereign-cloud 340; \
	$(MAKE) sync-wait-argoapp APP=projects-operator

uninstall-projects-operator: ## Delete Projects operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io projects-operator -n openshift-gitops --ignore-not-found; \
	echo "==> projects-operator Application deleted"

install-assignment-operator: ## Deploy Assignment operator via ArgoCD Application (OCI helm v0.1.3)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	CHART_VERSION=0.1.3 bash $(SCRIPTS_DIR)/apply-argoapp.sh assignment-operator assignment-operator sovereign-cloud 340; \
	$(MAKE) sync-wait-argoapp APP=assignment-operator

uninstall-assignment-operator: ## Delete Assignment operator ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io assignment-operator -n openshift-gitops --ignore-not-found; \
	echo "==> assignment-operator Application deleted"

install-sovereign-cloud-console: ## Deploy console plugin via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh sovereign-cloud-console sovereign-cloud-plugin sovereign-cloud 350; \
	$(MAKE) sync-wait-argoapp APP=sovereign-cloud-console

uninstall-sovereign-cloud-console: ## Delete sovereign-cloud-console ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io sovereign-cloud-console -n openshift-gitops --ignore-not-found; \
	echo "==> sovereign-cloud-console Application deleted"

##@ Uninstall All (Phase 2)

uninstall-all-operators: ## Delete all operator ArgoCD Applications (prune via ArgoCD)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	for app in rhacs-operator rhacm-operator openshift-pipelines-operator odf-operator \
	           quay-operator rhbk-operator eso-operator aap-operator; do \
	  oc delete application.argoproj.io $$app -n openshift-gitops --ignore-not-found 2>/dev/null; \
	  echo "  Deleted: $$app"; \
	done

uninstall-all-instances: ## Delete all instance/config ArgoCD Applications (reverse order)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	for app in sovereign-cloud-console assignment-operator projects-operator team-operator \
	           platformopenshift-operator cloudoso-operator cloudaws-operator entity-operator \
	           plugin-rbac dynamic-plugins-config custom-operators-pipelines custom-operators-git-creds \
	           rhacm-config rhacs-config service-oidc-config external-secrets-config \
	           keycloak-config vault-init rhacs-instance rhacm-instance quay-instance \
	           pipelines-bootstrap odf-noobaa gitea-instance rhbk-instance aap-instance \
	           vault-instance sovereign-cloud; do \
	  oc delete application.argoproj.io $$app -n openshift-gitops --ignore-not-found 2>/dev/null; \
	  echo "  Deleted: $$app"; \
	done

teardown-bootstrap: uninstall-all-instances uninstall-all-operators ## Delete all ArgoCD Applications (instances + operators)

# ===========================================================================
##@ Operator Build Pipelines (Phase 3) — Dedicated Tekton Pipelines per operator
# Each operator has its own named Pipeline in sovereign-cloud namespace.
# trigger-build-<name> creates a PipelineRun; wait-build-<name> waits for it.
# ===========================================================================

_trigger-op-build: ## Internal: create a PipelineRun for pipeline PIPELINE= in NS= with TAG=
	@test -n "$(PIPELINE)" || { echo "PIPELINE= required"; exit 1; }; \
	NS=$${NS:-sovereign-cloud}; \
	TAG=$${TAG:-latest}; \
	TMPF=$$(mktemp /tmp/pr-XXXXXX.yaml); \
	bash $(SCRIPTS_DIR)/make-pipelinerun.sh "$(PIPELINE)" "$$NS" "$$TAG" > "$$TMPF"; \
	oc create -n $$NS -f "$$TMPF" && echo "PipelineRun created for $(PIPELINE)"; \
	rm -f "$$TMPF"

_wait-op-build: ## Internal: wait for most recent PipelineRun for PIPELINE= in NS=
	@test -n "$(PIPELINE)" || { echo "PIPELINE= required"; exit 1; }; \
	NS=$${NS:-sovereign-cloud}; \
	PR=$$(oc get pipelinerun -n $$NS -l operator-pipeline=$(PIPELINE) \
	  --no-headers 2>/dev/null | sort -k5 -r | head -1 | awk '{print $$1}'); \
	if [ -z "$$PR" ]; then echo "No PipelineRun found for $(PIPELINE)"; exit 1; fi; \
	echo "==> Waiting for PipelineRun $$PR ($(PIPELINE))..."; \
	oc wait pipelinerun/$$PR -n $$NS --for=condition=Succeeded --timeout=900s

trigger-build-plugin-rbac: ## Trigger dedicated build pipeline for plugin-rbac
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=plugin-rbac-build

wait-build-plugin-rbac: ## Wait for plugin-rbac build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=plugin-rbac-build

trigger-build-entity-operator: ## Trigger dedicated build pipeline for entity-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=entity-operator-build

wait-build-entity-operator: ## Wait for entity-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=entity-operator-build

trigger-build-cloudaws: ## Trigger dedicated build pipeline for cloudaws-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=cloudaws-operator-build

wait-build-cloudaws: ## Wait for cloudaws-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=cloudaws-operator-build

trigger-build-cloudoso: ## Trigger dedicated build pipeline for cloudoso-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=cloudoso-operator-build

wait-build-cloudoso: ## Wait for cloudoso-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=cloudoso-operator-build

trigger-build-platformopenshift: ## Trigger dedicated build pipeline for platformopenshift-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=platformopenshift-operator-build

wait-build-platformopenshift: ## Wait for platformopenshift-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=platformopenshift-operator-build

trigger-build-team: ## Trigger dedicated build pipeline for team-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=team-operator-build

wait-build-team: ## Wait for team-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=team-operator-build

trigger-build-projects: ## Trigger dedicated build pipeline for projects-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=projects-operator-build

wait-build-projects: ## Wait for projects-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=projects-operator-build

trigger-build-assignment: ## Trigger dedicated build pipeline for assignment-operator
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=assignment-operator-build

wait-build-assignment: ## Wait for assignment-operator build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=assignment-operator-build

trigger-build-console: ## Trigger dedicated build pipeline for sovereign-cloud-console
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _trigger-op-build PIPELINE=sovereign-cloud-console-build

wait-build-console: ## Wait for sovereign-cloud-console build PipelineRun to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	$(MAKE) _wait-op-build PIPELINE=sovereign-cloud-console-build

trigger-build-all-operators: ## Trigger ALL operator build pipelines concurrently
	@$(SOURCE_BASHRC); $(MAKE) login; \
	for op in plugin-rbac-build entity-operator-build cloudaws-operator-build \
	           cloudoso-operator-build platformopenshift-operator-build \
	           team-operator-build projects-operator-build assignment-operator-build \
	           sovereign-cloud-console-build; do \
	  $(MAKE) _trigger-op-build PIPELINE=$$op; \
	done

wait-build-all-operators: ## Wait for ALL operator build PipelineRuns to succeed
	@$(SOURCE_BASHRC); $(MAKE) login; \
	for op in plugin-rbac-build entity-operator-build cloudaws-operator-build \
	           cloudoso-operator-build platformopenshift-operator-build \
	           team-operator-build projects-operator-build assignment-operator-build \
	           sovereign-cloud-console-build; do \
	  $(MAKE) _wait-op-build PIPELINE=$$op || echo "WARNING: $$op build may have failed"; \
	done

# ===========================================================================
##@ AAP with EDA (Phase 4) — Ansible Automation Platform + Event-Driven Ansible
# ===========================================================================

install-aap-instance: ## Deploy AAP instance (controller + EDA) via ArgoCD Application (OCI helm)
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	bash $(SCRIPTS_DIR)/apply-argoapp.sh aap-instance aap-instance ansible-automation-platform 115 \
		"appsDomain=$$APPS_DOMAIN"; \
	$(MAKE) sync-wait-argoapp APP=aap-instance

uninstall-aap-instance: ## Delete AAP instance ArgoCD Application
	@$(SOURCE_BASHRC); \
	$(MAKE) login; \
	oc delete application.argoproj.io aap-instance -n openshift-gitops --ignore-not-found; \
	echo "==> aap-instance Application deleted"

wait-aap-controller: ## Wait for AAP Controller to become Running
	@set -e; n=0; \
	until oc get ansibleautomationplatform central-aap -n aap \
	  -o jsonpath='{.status.conditions[?(@.type=="Successful")].status}' 2>/dev/null | grep -qi true; do \
	  n=$$((n+1)); echo "waiting AAP Controller ($$n/$(WAIT_ATTEMPTS))"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; echo "AAP: Controller Successful"

wait-aap-eda: ## Wait for AAP EDA to become Running
	@set -e; n=0; \
	until oc get eda -n aap -o name 2>/dev/null | grep -q eda; do \
	  n=$$((n+1)); echo "waiting AAP EDA deployment ($$n/$(WAIT_ATTEMPTS))"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; \
	EDA_NAME=$$(oc get eda -n aap -o name 2>/dev/null | head -1 | cut -d/ -f2); \
	until oc get eda $$EDA_NAME -n aap \
	  -o jsonpath='{.status.conditions[?(@.type=="Successful")].status}' 2>/dev/null | grep -qi true; do \
	  n=$$((n+1)); echo "waiting EDA Successful ($$n/$(WAIT_ATTEMPTS))"; \
	  [ $$n -gt $(WAIT_ATTEMPTS) ] && exit 1; sleep $(WAIT_INTERVAL); \
	done; echo "AAP EDA: Successful"

wait-aap-ready: wait-aap-controller ## Wait for AAP controller + EDA (EDA may take longer)
	@echo "==> AAP Controller is ready. EDA startup may take 10-15 min extra."
	@echo "==> Check EDA with: oc get eda -n aap"

status-aap: ## Show AAP and EDA status
	@echo "=== AnsibleAutomationPlatform ==="
	@oc get ansibleautomationplatform -n aap 2>&1 | head -10
	@echo "=== EDA (EventDrivenAnsible) ==="
	@oc get eda -n aap 2>&1 | head -10
	@echo "=== AAP Pods ==="
	@oc get pods -n aap 2>&1 | grep -E "Running|Error|Crash|Pending" | head -20
	@echo "=== AAP Routes ==="
	@oc get route -n aap 2>&1 | head -10
