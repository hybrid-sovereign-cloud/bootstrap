PLUGIN_QUAY_CHART_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../../../plugin_quay/helm)

.PHONY: upload-plugin-quay-chart
upload-plugin-quay-chart: ## Push plugin-quay Helm chart to OCI
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login $(OCI_HOST) -u '$$oauthtoken' --password-stdin
	helm lint $(PLUGIN_QUAY_CHART_DIR)
	helm package $(PLUGIN_QUAY_CHART_DIR) --destination /tmp/
	helm push /tmp/plugin-quay-$$(grep '^version:' $(PLUGIN_QUAY_CHART_DIR)/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/hybrid-sovereign
	@rm -f /tmp/plugin-quay-*.tgz
	$(call ok,plugin-quay chart uploaded)
