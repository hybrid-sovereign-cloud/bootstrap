##@ Build Artifacts

.PHONY: upload-acs-chart
upload-acs-chart: check-env ## Package and push ACS chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for acs chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"acs","visibility":"private","description":"Red Hat Advanced Cluster Security chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing ACS chart...$(RESET)"
	@helm package helm/charts/acs -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/acs/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/acs-$$(grep '^version:' helm/charts/acs/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,ACS chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/acs)
