PLUGIN_AAP_CHART_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../../../plugin_aap/helm)

.PHONY: upload-plugin-aap-chart
upload-plugin-aap-chart: ## Push plugin-aap Helm chart to OCI
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login $(OCI_HOST) -u '$$oauthtoken' --password-stdin
	helm lint $(PLUGIN_AAP_CHART_DIR)
	helm package $(PLUGIN_AAP_CHART_DIR) --destination /tmp/
	helm push /tmp/plugin-aap-$$(grep '^version:' $(PLUGIN_AAP_CHART_DIR)/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/hybrid-sovereign
	@rm -f /tmp/plugin-aap-*.tgz
	$(call ok,plugin-aap chart uploaded)
