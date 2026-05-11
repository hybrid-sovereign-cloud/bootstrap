PLUGIN_VAULT_CHART_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)/plugin_vault/helm
PLUGIN_VAULT_CHART_VERSION := $(shell grep '^version:' $(PLUGIN_VAULT_CHART_DIR)/Chart.yaml 2>/dev/null | awk '{print $$2}')

.PHONY: upload-plugin-vault-chart
upload-plugin-vault-chart: ## Package and push plugin-vault Helm chart to OCI
	@echo "── Logging in to $(OCI_HOST) ──"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login $(OCI_HOST) -u '$$oauthtoken' --password-stdin
	$(call ok,Logged in to $(OCI_HOST))
	@echo "Packaging and pushing plugin-vault chart..."
	@helm package $(PLUGIN_VAULT_CHART_DIR) --destination /tmp/
	@helm push /tmp/plugin-vault-$(PLUGIN_VAULT_CHART_VERSION).tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	@rm -f /tmp/plugin-vault-$(PLUGIN_VAULT_CHART_VERSION).tgz
	$(call ok,plugin-vault chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/plugin-vault)
