PLUGIN_AAP_CHART_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)/plugin_aap/helm
PLUGIN_AAP_CHART_VERSION := $(shell grep '^version:' $(PLUGIN_AAP_CHART_DIR)/Chart.yaml 2>/dev/null | awk '{print $$2}')

.PHONY: upload-plugin-aap-chart
upload-plugin-aap-chart: ## Package and push plugin-aap Helm chart to OCI
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login $(OCI_HOST) -u '$$oauthtoken' --password-stdin
	$(call ok,Logged in to $(OCI_HOST))
	@echo "Packaging and pushing plugin-aap chart..."
	@helm package $(PLUGIN_AAP_CHART_DIR) --destination /tmp/
	@helm push /tmp/plugin-aap-$(PLUGIN_AAP_CHART_VERSION).tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	@rm -f /tmp/plugin-aap-$(PLUGIN_AAP_CHART_VERSION).tgz
	$(call ok,plugin-aap chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/plugin-aap)
