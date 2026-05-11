##@ Build Artifacts

ENTITY_CHART_REPO ?= ../Entity

.PHONY: upload-entity-operator-chart
upload-entity-operator-chart: check-env ## Package and push entity-operator Helm chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for entity-operator chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"entity-operator","visibility":"private","description":"Entity Operator Helm chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing entity-operator chart...$(RESET)"
	@helm package $(ENTITY_CHART_REPO)/helm -d /tmp/helm-pkg > /dev/null
	@CHART_VER=$$(grep '^version:' $(ENTITY_CHART_REPO)/helm/Chart.yaml | awk '{print $$2}'); \
	 helm push /tmp/helm-pkg/entity-operator-$${CHART_VER}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,entity-operator chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/entity-operator)
