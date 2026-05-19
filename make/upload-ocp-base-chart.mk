##@ Build Artifacts — ocp-base

.PHONY: upload-ocp-base-chart
upload-ocp-base-chart: check-env ## Package and push ocp-base chart to OCI registry (public visibility)
	@echo "$(BOLD)Ensuring Quay repository for ocp-base chart (public)...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"ocp-base","visibility":"public","description":"Base OCP cluster config: ESO + OpenShift GitOps","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@curl -sf -X POST \
	  "https://$(OCI_HOST)/api/v1/repository/$(OCI_NAMESPACE)/ocp-base/changevisibility" \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"visibility":"public"}' > /dev/null 2>&1 || true
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing ocp-base chart...$(RESET)"
	@helm package helm/charts/ocp-base -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/ocp-base/Chart.yaml | awk '{print $$2}') > /dev/null 2>&1 || \
	  helm package ../charts/charts/ocp-base -d /tmp/helm-pkg --version $$(grep '^version:' ../charts/charts/ocp-base/Chart.yaml | awk '{print $$2}') > /dev/null
	@CHART_VERSION=$$(grep '^version:' helm/charts/ocp-base/Chart.yaml 2>/dev/null || grep '^version:' ../charts/charts/ocp-base/Chart.yaml | awk '{print $$2}'); \
	  helm push /tmp/helm-pkg/ocp-base-$${CHART_VERSION}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,ocp-base chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/ocp-base)
