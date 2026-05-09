##@ Build Artifacts

.PHONY: upload-rhbk-chart
upload-rhbk-chart: check-env ## Push RHBK (Keycloak) Helm chart to OCI registry
	@echo "$(BOLD)Creating Quay repository for RHBK chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"rhbk","visibility":"private","description":"Red Hat Build of Keycloak chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Pushing RHBK chart to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin
	@rm -rf /tmp/helm-pkg && helm package helm/charts/rhbk --destination /tmp/helm-pkg
	@helm push /tmp/helm-pkg/rhbk-*.tgz "oci://$(OCI_HOST)/$(OCI_NAMESPACE)"
	$(call ok,RHBK chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/rhbk)
