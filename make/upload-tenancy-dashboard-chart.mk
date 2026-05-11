##@ Build Artifacts

TENANCY_DASHBOARD_CHART_REPO ?= ../tenancy_dashboard

.PHONY: upload-tenancy-dashboard-chart
upload-tenancy-dashboard-chart: check-env ## Package and push tenancy-dashboard Helm chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for tenancy-dashboard chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"tenancy-dashboard","visibility":"private","description":"Tenancy Dashboard Helm chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing tenancy-dashboard chart...$(RESET)"
	@helm package $(TENANCY_DASHBOARD_CHART_REPO)/helm/charts/dashboard -d /tmp/helm-pkg > /dev/null
	@CHART_VER=$$(grep '^version:' $(TENANCY_DASHBOARD_CHART_REPO)/helm/charts/dashboard/Chart.yaml | awk '{print $$2}'); \
	 helm push /tmp/helm-pkg/tenancy-dashboard-$${CHART_VER}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,tenancy-dashboard chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/tenancy-dashboard)
