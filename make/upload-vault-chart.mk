##@ Build Artifacts

.PHONY: upload-vault-chart
upload-vault-chart: check-env ## Package and push Vault chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for vault chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"vault","visibility":"private","description":"HashiCorp Vault HA chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing Vault chart...$(RESET)"
	@helm dependency build helm/charts/vault > /dev/null 2>&1 || true
	@helm package helm/charts/vault -d /tmp/helm-pkg > /dev/null
	@CHART_VER=$$(helm show chart helm/charts/vault | grep '^version:' | awk '{print $$2}'); \
	 helm push /tmp/helm-pkg/vault-$${CHART_VER}.tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,Vault chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/vault)
