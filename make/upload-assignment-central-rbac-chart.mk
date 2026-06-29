##@ Build Artifacts

ASSIGNMENT_CENTRAL_RBAC_CHART_REPO ?= ../Assignment/charts/assignment-central-rbac

.PHONY: upload-assignment-central-rbac-chart
upload-assignment-central-rbac-chart: check-env ## Package and push assignment-central-rbac chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for assignment-central-rbac chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"assignment-central-rbac","visibility":"private","description":"Assignment central RBAC chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing assignment-central-rbac chart...$(RESET)"
	@helm package $(ASSIGNMENT_CENTRAL_RBAC_CHART_REPO) -d /tmp/helm-pkg > /dev/null
	@CHART_VER=$$(grep '^version:' $(ASSIGNMENT_CENTRAL_RBAC_CHART_REPO)/Chart.yaml | awk '{print $$2}'); \
	 helm push /tmp/helm-pkg/assignment-central-rbac-$${CHART_VER}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,assignment-central-rbac chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/assignment-central-rbac)
