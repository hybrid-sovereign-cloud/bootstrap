.PHONY: help login import-architecture import-initrepos \
	install-aap-operator install-eso-operator install-rhbk-operator \
	install-gitops-operator install-quay-operator install-all-operators \
	install-aap-instance install-vault-instance install-rhbk-instance \
	install-gitops-instance install-gitea-instance install-sovereign-cloud \
	install-all-instances install-config-chart \
	vault-init keycloak-config external-secrets-config \
	install-odf-operator install-quay-instance \
	uninstall-all-operators uninstall-all-instances \
	approve-rhbk-installplan status

SHELL := /bin/bash

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

# Instance chart paths
AAP_INST_CHART    := $(CHARTS_DIR)/instances/aap-instance
VAULT_INST_CHART  := $(CHARTS_DIR)/instances/vault-instance
RHBK_INST_CHART   := $(CHARTS_DIR)/instances/rhbk-instance
GITOPS_INST_CHART := $(CHARTS_DIR)/instances/gitops-instance
GITEA_INST_CHART  := $(CHARTS_DIR)/instances/gitea-instance
SC_CHART          := $(CHARTS_DIR)/instances/sovereign-cloud
QUAY_INST_CHART   := $(CHARTS_DIR)/instances/quay-instance

# Config chart paths
VAULT_INIT_CHART  := $(CHARTS_DIR)/config/vault-init
KC_CONFIG_CHART   := $(CHARTS_DIR)/config/keycloak-config
ESO_CONFIG_CHART  := $(CHARTS_DIR)/config/external-secrets-config

##@ Help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Cluster Access
login: ## Login to OpenShift cluster
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

install-gitops-operator: ## Install OpenShift GitOps operator (cluster-scoped)
	helm upgrade --install gitops-operator $(GITOPS_OP_CHART) \
		--namespace openshift-gitops --create-namespace

install-quay-operator: ## Install Quay operator (namespace-scoped)
	helm upgrade --install quay-operator $(QUAY_OP_CHART) \
		--namespace quay --create-namespace

install-all-operators: install-aap-operator install-eso-operator install-rhbk-operator install-gitops-operator install-quay-operator ## Install all operators

approve-rhbk-installplan: ## Approve pending RHBK Manual InstallPlan
	@ip=$$(oc get installplan -n rhbk -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null); \
	if [ -n "$$ip" ]; then \
		echo "Approving RHBK InstallPlan: $$ip"; \
		oc patch installplan $$ip -n rhbk --type merge -p '{"spec":{"approved":true}}'; \
	else \
		echo "No pending RHBK InstallPlan to approve."; \
	fi

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
	$(eval APPS_DOMAIN := $(shell oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'))
	helm upgrade --install rhbk-instance $(RHBK_INST_CHART) \
		--namespace rhbk --create-namespace \
		--set "hostname=keycloak-rhbk.$(APPS_DOMAIN)"

install-gitops-instance: ## Install GitOps ArgoCD instance
	helm upgrade --install gitops-instance $(GITOPS_INST_CHART) \
		--namespace openshift-gitops --create-namespace

install-gitea-instance: ## Install Gitea in gitea namespace
	helm upgrade --install gitea-instance $(GITEA_INST_CHART) \
		--namespace gitea --create-namespace

install-all-instances: install-sovereign-cloud install-aap-instance install-vault-instance install-rhbk-instance ## Install core instances

##@ Configuration
vault-init: ## Initialize Vault, create unseal secret, central KV
	helm upgrade --install vault-init $(VAULT_INIT_CHART) \
		--namespace vault --create-namespace

keycloak-config: ## Configure Keycloak realm, users, clients, store secrets in Vault
	$(eval APPS_DOMAIN := $(shell oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'))
	helm upgrade --install keycloak-config $(KC_CONFIG_CHART) \
		--namespace rhbk --create-namespace \
		--set "keycloakUrl=https://keycloak-rhbk.$(APPS_DOMAIN)"

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

##@ Uninstall
uninstall-all-instances: ## Uninstall all instances
	-helm uninstall vault-init -n vault
	-helm uninstall keycloak-config -n rhbk
	-helm uninstall eso-config -n sovereign-cloud
	-helm uninstall quay-instance -n quay
	-helm uninstall gitea-instance -n gitea
	-helm uninstall rhbk-instance -n rhbk
	-helm uninstall vault-instance -n vault
	-helm uninstall aap-instance -n aap
	-helm uninstall gitops-instance -n openshift-gitops
	-helm uninstall sovereign-cloud -n sovereign-cloud

uninstall-all-operators: ## Uninstall all operators
	-helm uninstall odf-operator -n openshift-storage
	-helm uninstall quay-operator -n quay
	-helm uninstall gitops-operator -n openshift-gitops
	-helm uninstall rhbk-operator -n rhbk
	-helm uninstall eso-operator -n external-secrets-operator
	-helm uninstall aap-operator -n ansible-automation-platform

##@ Status
status: ## Show status of all helm releases and key resources
	@echo "=== Helm Releases ==="; helm list -A 2>&1
	@echo "=== Operator CSVs ==="; oc get csv -A 2>&1 | grep -E "(Succeeded|Failed|Installing|Pending)" | head -20
	@echo "=== Key Pods ==="; oc get pods -n vault 2>&1; oc get pods -n aap 2>&1; oc get pods -n rhbk 2>&1
