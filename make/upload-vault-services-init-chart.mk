##@ Build Artifacts

.PHONY: upload-vault-services-init-chart
upload-vault-services-init-chart: check-env ## Package and push vault-services-init chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for vault-services-init chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"vault-services-init","visibility":"private","description":"Vault Services in-cluster init Job chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing vault-services-init chart...$(RESET)"
	@helm package helm/charts/vault-services-init -d /tmp/helm-pkg > /dev/null
	@helm push /tmp/helm-pkg/vault-services-init-$$(grep '^version:' helm/charts/vault-services-init/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,vault-services-init chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/vault-services-init)
