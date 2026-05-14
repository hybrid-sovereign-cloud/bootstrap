##@ Build Artifacts

.PHONY: upload-vault-central-namespace-chart
upload-vault-central-namespace-chart: check-env ## Package and push vault-central-namespace chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for vault-central-namespace chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"vault-central-namespace","visibility":"private","description":"Vault central namespace init secrets backup chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing vault-central-namespace chart...$(RESET)"
	@mkdir -p /tmp/helm-pkg
	@helm package helm/charts/vault-central-namespace -d /tmp/helm-pkg > /dev/null
	@CHART_VER=$$(grep '^version:' helm/charts/vault-central-namespace/Chart.yaml | awk '{print $$2}'); \
	 helm push /tmp/helm-pkg/vault-central-namespace-$${CHART_VER}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,vault-central-namespace chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/vault-central-namespace)
