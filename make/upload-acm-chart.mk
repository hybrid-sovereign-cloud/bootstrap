##@ Build Artifacts

.PHONY: upload-acm-chart
upload-acm-chart: check-env ## Create Quay OCI repo and push the RHACM Helm chart (uses admin token)
	@echo "$(BOLD)Creating Quay OCI repository for RHACM chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"rhacm","visibility":"private","description":"RHACM operator Helm chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" \
	  && printf "  $(GREEN)✓$(RESET)  OCI repository $(OCI_NAMESPACE)/rhacm created (or already exists)\n" \
	  || printf "  $(RED)✗$(RESET)  Repository create returned non-2xx (may already exist — continuing)\n"
	@echo "$(BOLD)Pushing RHACM chart to OCI registry (admin token)...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' \
	  --password-stdin
	@rm -rf /tmp/helm-pkg && helm package helm/charts/rhacm --destination /tmp/helm-pkg
	@helm push /tmp/helm-pkg/rhacm-*.tgz "oci://$(OCI_HOST)/$(OCI_NAMESPACE)"
	$(call ok,RHACM chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/rhacm)
