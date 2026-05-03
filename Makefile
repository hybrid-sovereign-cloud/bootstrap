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
	vault-init vault-enable-kv vault-store-gitea-admin vault-store-github-token vault-store-keycloak-auth keycloak-config external-secrets-config fix-csv-operator-groups fix-gitea-scc \
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
	validate-helm verify-pipelines-bootstrap rebuild-all

SHELL := /bin/bash

# Source user shell profile (PATH, aliases) — optional for automation.
SOURCE_BASHRC := { set +eu; . $${HOME}/.bashrc 2>/dev/null; set -eu; } 2>/dev/null || true
WAIT_INTERVAL ?= 15
WAIT_ATTEMPTS ?= 120

# Git remote for Argo CD + ApplicationSet (HTTPS URL with org/repo). Personal access token required.
GITHUB_URL ?=
GITHUB_TOKEN ?=
GITHUB_REVISION ?= main
export GITHUB_REVISION

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
	helm upgrade --install platform-applicationset $(GITOPS_APPS_CHART) \
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
	@echo "================================================================"
	@echo "  Rebuild complete. Run 'make status' to verify all components."
	@echo "================================================================"

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

install-gitops-instance: ## Apply gitops-instance chart (ArgoCD CR + repo secret). Reads GITHUB_URL/GITHUB_TOKEN from env/.env if set.
	@set -euo pipefail; \
	set -a; [ -f .env ] && . ./.env || true; set +a; \
	APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo ""); \
	helm upgrade --install gitops-instance $(GITOPS_INST_CHART) \
		--namespace openshift-gitops --create-namespace \
		$${APPS_DOMAIN:+--set argocd.appsDomain="$$APPS_DOMAIN"} \
		$${GITHUB_URL:+--set-string github.repositoryUrl="$$GITHUB_URL"} \
		$${GITHUB_TOKEN:+--set-string github.token="$$GITHUB_TOKEN"} \
		$${GITHUB_URL:+--set-string github.insecure="true"} \
		$${GITHUB_URL:+--set-string github.username="git"}

install-gitops-instance-repos: ## Configure Argo CD repository secret (requires GITHUB_URL and GITHUB_TOKEN)
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$${GITHUB_URL:-}" && test -n "$${GITHUB_TOKEN:-}" || { echo "Set GITHUB_URL and GITHUB_TOKEN (e.g. in .env)."; exit 1; }; \
	$(MAKE) install-gitops-instance

install-gitea-instance: ## Install Gitea in gitea namespace (DOMAIN/ROOT_URL from cluster ingress domain)
	@APPS_DOMAIN=$$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'); \
	test -n "$$APPS_DOMAIN" || { echo "Could not read cluster apps domain."; exit 1; }; \
	helm upgrade --install gitea-instance $(GITEA_INST_CHART) \
		--namespace gitea --create-namespace \
		--set-string gitea.gitea.config.server.DOMAIN=gitea.$$APPS_DOMAIN \
		--set-string gitea.gitea.config.server.ROOT_URL=https://gitea.$$APPS_DOMAIN \
		--set gitea.route.enabled=true \
		--set-string gitea.route.host=gitea.$$APPS_DOMAIN \
		--set-string gitea.route.tls.termination=edge

install-pipelines-bootstrap: ## Install ImageStream + sample Tekton pipeline in sovereign-cloud (requires OpenShift Pipelines)
	helm upgrade --install pipelines-bootstrap $(PIPELINES_BOOT_CHART) \
		--namespace sovereign-cloud --create-namespace

install-all-instances: install-sovereign-cloud install-aap-instance install-vault-instance install-rhbk-instance ## Install core instances (add pipelines-bootstrap after operators)

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

install-rhacm-operator: ## Install RHACM OLM subscription (open-cluster-management ns)
	helm upgrade --install rhacm-operator $(RHACM_OP_CHART) \
		--namespace open-cluster-management --create-namespace

install-rhacs-operator: ## Install RHACS OLM subscription (rhacs-operator ns)
	helm upgrade --install rhacs-operator $(RHACS_OP_CHART) \
		--namespace rhacs-operator --create-namespace

install-rhacm-instance: ## Install RHACM MultiClusterHub
	helm upgrade --install rhacm-instance $(RHACM_INST_CHART) \
		--namespace open-cluster-management --create-namespace

install-rhacs-instance: ## Install RHACS Central + SecuredCluster
	helm upgrade --install rhacs-instance $(RHACS_INST_CHART) \
		--namespace stackrox --create-namespace

install-rhacs-config: ## Run RHACS post-install config (init-bundle, Vault secret storage)
	helm upgrade --install rhacs-config $(RHACS_CONFIG_CHART) \
		--namespace stackrox

install-rhacm-config: ## Run RHACM post-install config (ManagedClusterSet)
	helm upgrade --install rhacm-config $(RHACM_CONFIG_CHART) \
		--namespace open-cluster-management

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

##@ Uninstall
uninstall-pipelines-bootstrap: ## Remove pipelines-bootstrap Helm release
	-helm uninstall pipelines-bootstrap -n sovereign-cloud

uninstall-all-instances: ## Uninstall all instance/config releases (reverse dependency order)
	-helm uninstall rhacs-config -n stackrox
	-helm uninstall rhacm-config -n open-cluster-management
	-helm uninstall service-oidc-config -n sovereign-cloud
	-helm uninstall external-secrets-config -n sovereign-cloud
	-helm uninstall vault-init -n vault
	-helm uninstall keycloak-config -n rhbk
	-helm uninstall eso-config -n sovereign-cloud
	-helm uninstall pipelines-bootstrap -n sovereign-cloud
	-helm uninstall odf-noobaa -n openshift-storage
	-helm uninstall quay-instance -n quay
	-helm uninstall rhacs-instance -n stackrox
	-helm uninstall rhacm-instance -n open-cluster-management
	-helm uninstall gitea-instance -n gitea
	-helm uninstall rhbk-instance -n rhbk
	-helm uninstall vault-instance -n vault
	-helm uninstall aap-instance -n aap
	-helm uninstall gitops-instance -n openshift-gitops
	-helm uninstall sovereign-cloud -n sovereign-cloud

uninstall-all-operators: ## Uninstall all operator Helm releases
	-helm uninstall rhacs-operator -n rhacs-operator
	-helm uninstall rhacm-operator -n open-cluster-management
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

##@ Custom Operators

install-custom-operators-git-creds: ## Install ArgoCD org credential template for hybrid-sovereign-cloud GitHub org
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	$(MAKE) login; \
	test -n "$${GITHUB_TOKEN:-}" || { echo "GITHUB_TOKEN is required."; exit 1; }; \
	helm upgrade --install custom-operators-git-creds $(CUSTOM_OPS_GIT_CREDS_CHART) \
		--namespace openshift-gitops --create-namespace \
		--set-string githubToken="$$GITHUB_TOKEN"

install-custom-operators-pipelines: ## Install Tekton pipelines and ImageStreams for all 8 custom operators
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	$(MAKE) login; \
	helm upgrade --install custom-operators-pipelines $(CUSTOM_OPS_PIPELINES_CHART) \
		--namespace sovereign-cloud --create-namespace

install-custom-operators-applicationset: ## Install ArgoCD ApplicationSet for the 8 custom operators
	@set -euo pipefail; \
	$(SOURCE_BASHRC); \
	set -a; [ -f .env ] && . ./.env; set +a; \
	$(MAKE) login; \
	helm upgrade --install custom-operators-applicationset $(CUSTOM_OPS_APPSET_CHART) \
		--namespace openshift-gitops --create-namespace

fix-gitea-scc: ## Grant anyuid SCC to Gitea default SA (needed for init-directories chmod)
	@oc adm policy add-scc-to-user anyuid -z default -n gitea 2>&1 || true
	@oc rollout restart deployment gitea -n gitea 2>&1 || true
	@echo "Gitea anyuid SCC granted and rollout restarted"

deploy-custom-operators: install-custom-operators-git-creds install-custom-operators-pipelines install-custom-operators-applicationset ## Deploy all custom operator prereqs + ApplicationSet

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
