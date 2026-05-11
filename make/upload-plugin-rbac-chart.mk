##@ Build Artifacts

PLUGIN_RBAC_CHART_REPO ?= ../plugin_rbac

.PHONY: upload-plugin-rbac-chart
upload-plugin-rbac-chart: check-env ## Package and push plugin-rbac Helm chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for plugin-rbac chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"plugin-rbac","visibility":"private","description":"Plugin RBAC Operator Helm chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing plugin-rbac chart...$(RESET)"
	@helm package $(PLUGIN_RBAC_CHART_REPO)/helm -d /tmp/helm-pkg > /dev/null
	@CHART_VER=$$(grep '^version:' $(PLUGIN_RBAC_CHART_REPO)/helm/Chart.yaml | awk '{print $$2}'); \
	 helm push /tmp/helm-pkg/plugin-rbac-$${CHART_VER}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,plugin-rbac chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/plugin-rbac)
