##@ Build Artifacts

.PHONY: upload-sovereign-namespaces-chart
upload-sovereign-namespaces-chart: check-env ## Push sovereign-namespaces Helm chart to OCI registry
	@echo "$(BOLD)Creating Quay repository for sovereign-namespaces chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"sovereign-namespaces","visibility":"private","description":"Sovereign cloud namespace chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Pushing sovereign-namespaces chart to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin
	@rm -rf /tmp/helm-pkg && helm package helm/charts/sovereign-namespaces --destination /tmp/helm-pkg
	@helm push /tmp/helm-pkg/sovereign-namespaces-*.tgz "oci://$(OCI_HOST)/$(OCI_NAMESPACE)"
	$(call ok,sovereign-namespaces chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/sovereign-namespaces)
