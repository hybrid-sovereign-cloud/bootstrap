.PHONY: help login import-architecture import-initrepos \
	phase1-gitops phase2-applicationset gitops-full-bootstrap uninstall-platform-applicationset \
	install-aap-operator install-eso-operator install-rhbk-operator \
	install-gitops-operator install-quay-operator install-openshift-pipelines-operator \
	install-all-operators install-all-operators-with-storage \
	install-aap-instance install-vault-instance install-rhbk-instance \
	install-gitops-instance install-gitops-instance-repos install-gitea-instance install-sovereign-cloud \
	install-all-instances install-pipelines-bootstrap \
	wait-openshift-gitops-csv wait-argocd-ready wait-csv-succeeded \
	argocd-post-sync-waits verify-argocd-app-health \
	vault-init keycloak-config external-secrets-config \
	install-odf-operator install-odf-noobaa install-quay-instance \
	uninstall-all-operators uninstall-all-instances uninstall-pipelines-bootstrap \
	teardown-bootstrap delete-bootstrap-namespaces approve-rhbk-installplan status \
	validate-helm verify-pipelines-bootstrap

SHELL := /bin/bash

# Source user shell profile (PATH, aliases) — optional for automation.
SOURCE_BASHRC := source $${HOME}/.bashrc 2>/dev/null || true
WAIT_INTERVAL ?= 15
WAIT_ATTEMPTS ?= 120

# Git remote for Argo CD + ApplicationSet (HTTPS URL with org/repo). Personal access token required.
GITHUB_URL ?=
GITHUB_TOKEN ?=
GITHUB_REVISION ?= main

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

# Instance chart paths
AAP_INST_CHART    := $(CHARTS_DIR)/instances/aap-instance
VAULT_INST_CHART  := $(CHARTS_DIR)/instances/vault-instance
RHBK_INST_CHART   := $(CHARTS_DIR)/instances/rhbk-instance
GITOPS_INST_CHART := $(CHARTS_DIR)/instances/gitops-instance
GITEA_INST_CHART  := $(CHARTS_DIR)/instances/gitea-instance
SC_CHART          := $(CHARTS_DIR)/instances/sovereign-cloud
QUAY_INST_CHART   := $(CHARTS_DIR)/instances/quay-instance
PIPELINES_BOOT_CHART := $(CHARTS_DIR)/instances/pipelines-bootstrap
GITOPS_APPS_CHART     := $(CHARTS_DIR)/gitops/platform-applicationset

# Config chart paths
VAULT_INIT_CHART  := $(CHARTS_DIR)/config/vault-init
KC_CONFIG_CHART   := $(CHARTS_DIR)/config/keycloak-config
ESO_CONFIG_CHART  := $(CHARTS_DIR)/config/external-secrets-config

# Namespaces managed by this bootstrap (for teardown). Optional: DELETE_OPENSHIFT_STORAGE_NS=1
BOOTSTRAP_NAMESPACES := ansible-automation-platform external-secrets-operator \
	rhbk openshift-gitops quay vault aap gitea sovereign-cloud

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
	helm upgrade --install platform-applicationset $(GITOPS_APPS_CHART) \
		--namespace openshift-gitops --create-namespace \
		--set-string appsDomain="$$APPS_DOMAIN" \
		--set-string git.repoURL="$$GITHUB_URL" \
		--set-string git.revision="$$GITHUB_REVISION"

gitops-full-bootstrap: phase1-gitops phase2-applicationset ## Run phase1 then phase2

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
	oc login "$$OCP_SERVER" -u "$$OCP_USERNAME" -p "$$OCP_PASSWORD" --insecure-skip-tls-verify

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

##@ Operators (OLM Subscriptions)
install-aap-operator: ## Install AAP operator (namespace-scoped)
	helm upgrade --install aap-operator $(AAP_OP_CHART) \
		--namespace ansible-automation-platform --create-namespace

install-eso-operator: ## Install External Secrets operator (namespace-scoped)
	helm upgrade --install eso-operator $(ESO_OP_CHART) \
		--namespace external-secrets-operator --create-namespace

install-rhbk-operator: ## Install RHBK operator (namespace-scoped)
	helm upgrade --install rhbk-operator $(RHBK_OP_CHART) \
		--namespace rhbk --create-namespace

install-gitops-operator: ## Install OpenShift GitOps operator (cluster-scoped OperatorGroup)
	helm upgrade --install gitops-operator $(GITOPS_OP_CHART) \
		--namespace openshift-gitops --create-namespace

install-quay-operator: ## Install Quay operator (namespace-scoped)
	helm upgrade --install quay-operator $(QUAY_OP_CHART) \
		--namespace quay --create-namespace

install-openshift-pipelines-operator: ## Install Red Hat OpenShift Pipelines (subscription in openshift-operators)
	helm upgrade --install openshift-pipelines-operator $(PIPELINES_OP_CHART) \
		--namespace openshift-operators

install-all-operators: install-aap-operator install-eso-operator install-rhbk-operator install-gitops-operator install-quay-operator install-openshift-pipelines-operator ## Install core operators (no ODF)

install-all-operators-with-storage: install-all-operators install-odf-operator ## Core operators plus ODF

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

##@ Instances (Operand CRs / Workloads)
install-sovereign-cloud: ## Create sovereign-cloud foundation namespace
	helm upgrade --install sovereign-cloud $(SC_CHART) \
		--namespace sovereign-cloud --create-namespace

install-aap-instance: ## Install AAP instance in aap namespace
	helm upgrade --install aap-instance $(AAP_INST_CHART) \
		--namespace aap --create-namespace

install-vault-instance: ## Install Vault in vault namespace
	helm upgrade --install vault-instance $(VAULT_INST_CHART) \
		--namespace vault --create-namespace

install-rhbk-instance: ## Install Keycloak instance in rhbk namespace
	@APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	helm upgrade --install rhbk-instance $(RHBK_INST_CHART) \
		--namespace rhbk --create-namespace \
		--set "hostname=keycloak-rhbk.$$APPS_DOMAIN"

install-gitops-instance: ## Install GitOps metadata chart only (legacy; prefer install-gitops-instance-repos)
	helm upgrade --install gitops-instance $(GITOPS_INST_CHART) \
		--namespace openshift-gitops --create-namespace

install-gitops-instance-repos: ## Configure Argo CD repository secret + optional server flags (GITHUB_URL, GITHUB_TOKEN)
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$${GITHUB_URL:-}" && test -n "$${GITHUB_TOKEN:-}" || { echo "Set GITHUB_URL and GITHUB_TOKEN (e.g. in .env)."; exit 1; }; \
	helm upgrade --install gitops-instance $(GITOPS_INST_CHART) \
		--namespace openshift-gitops --create-namespace \
		--set-string github.repositoryUrl="$$GITHUB_URL" \
		--set-string github.token="$$GITHUB_TOKEN" \
		--set-string github.insecure="true" \
		--set-string github.username="git"

install-gitea-instance: ## Install Gitea in gitea namespace
	helm upgrade --install gitea-instance $(GITEA_INST_CHART) \
		--namespace gitea --create-namespace

install-pipelines-bootstrap: ## Install ImageStream + sample Tekton pipeline in sovereign-cloud (requires OpenShift Pipelines)
	helm upgrade --install pipelines-bootstrap $(PIPELINES_BOOT_CHART) \
		--namespace sovereign-cloud --create-namespace

install-all-instances: install-sovereign-cloud install-aap-instance install-vault-instance install-rhbk-instance ## Install core instances (add pipelines-bootstrap after operators)

##@ Configuration
vault-init: ## Initialize Vault, create unseal secret, central KV
	helm upgrade --install vault-init $(VAULT_INIT_CHART) \
		--namespace vault --create-namespace

keycloak-config: ## Configure Keycloak realm, users, clients, store secrets in Vault
	@APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	helm upgrade --install keycloak-config $(KC_CONFIG_CHART) \
		--namespace rhbk --create-namespace \
		--set "keycloakUrl=https://keycloak-rhbk.$$APPS_DOMAIN"

external-secrets-config: ## Configure ExternalSecrets + SecretStore
	helm upgrade --install eso-config $(ESO_CONFIG_CHART) \
		--namespace sovereign-cloud --create-namespace

##@ ODF & Quay
install-odf-operator: ## Install ODF operator (object storage only)
	helm upgrade --install odf-operator $(ODF_OP_CHART) \
		--namespace openshift-storage --create-namespace

install-odf-noobaa: ## Install NooBaa for S3-compatible object storage
	helm upgrade --install odf-noobaa $(CHARTS_DIR)/instances/odf-noobaa \
		--namespace openshift-storage

install-quay-instance: ## Install Quay registry
	helm upgrade --install quay-instance $(QUAY_INST_CHART) \
		--namespace quay --create-namespace

##@ Pipelines verify (read-only oc)
verify-pipelines-bootstrap: ## Show Pipeline + ImageStream (requires login); start runs from console/tkn
	oc get pipeline,imagestream -n sovereign-cloud

##@ Uninstall
uninstall-pipelines-bootstrap: ## Remove pipelines-bootstrap Helm release
	-helm uninstall pipelines-bootstrap -n sovereign-cloud

uninstall-all-instances: ## Uninstall all instance/config releases (reverse dependency order)
	-helm uninstall vault-init -n vault
	-helm uninstall keycloak-config -n rhbk
	-helm uninstall eso-config -n sovereign-cloud
	-helm uninstall pipelines-bootstrap -n sovereign-cloud
	-helm uninstall odf-noobaa -n openshift-storage
	-helm uninstall quay-instance -n quay
	-helm uninstall gitea-instance -n gitea
	-helm uninstall rhbk-instance -n rhbk
	-helm uninstall vault-instance -n vault
	-helm uninstall aap-instance -n aap
	-helm uninstall gitops-instance -n openshift-gitops
	-helm uninstall sovereign-cloud -n sovereign-cloud

uninstall-all-operators: ## Uninstall all operator Helm releases
	-helm uninstall openshift-pipelines-operator -n openshift-operators
	-helm uninstall odf-operator -n openshift-storage
	-helm uninstall quay-operator -n quay
	-helm uninstall gitops-operator -n openshift-gitops
	-helm uninstall rhbk-operator -n rhbk
	-helm uninstall eso-operator -n external-secrets-operator
	-helm uninstall aap-operator -n ansible-automation-platform

teardown-bootstrap: uninstall-platform-applicationset uninstall-all-instances uninstall-all-operators ## Helm uninstall GitOps ApplicationSet, instances, operators

uninstall-platform-applicationset: ## Remove ApplicationSet Helm release (Applications may remain until deleted)
	-helm uninstall platform-applicationset -n openshift-gitops

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

##@ Status
status: ## Show status of all helm releases and key resources
	@echo "=== Helm Releases ==="; helm list -A 2>&1
	@echo "=== Operator CSVs ==="; oc get csv -A 2>&1 | grep -E "(Succeeded|Failed|Installing|Pending)" | head -30
	@echo "=== Key Pods ==="; oc get pods -n vault 2>&1; oc get pods -n aap 2>&1; oc get pods -n rhbk 2>&1
