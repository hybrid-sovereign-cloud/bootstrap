PLUGIN_QUAY_CHART_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../..)/plugin_quay/helm
PLUGIN_QUAY_CHART_VERSION := $(shell grep '^version:' $(PLUGIN_QUAY_CHART_DIR)/Chart.yaml 2>/dev/null | awk '{print $$2}')

.PHONY: upload-plugin-quay-chart
upload-plugin-quay-chart: ## Package and push plugin-quay Helm chart to OCI
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login $(OCI_HOST) -u '$$oauthtoken' --password-stdin
	$(call ok,Logged in to $(OCI_HOST))
	@echo "Packaging and pushing plugin-quay chart..."
	@helm package $(PLUGIN_QUAY_CHART_DIR) --destination /tmp/
	@helm push /tmp/plugin-quay-$(PLUGIN_QUAY_CHART_VERSION).tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	@rm -f /tmp/plugin-quay-$(PLUGIN_QUAY_CHART_VERSION).tgz
	$(call ok,plugin-quay chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/plugin-quay)
