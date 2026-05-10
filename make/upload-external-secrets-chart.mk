##@ Build Artifacts

.PHONY: upload-external-secrets-chart
upload-external-secrets-chart: check-env ## Package and push External Secrets chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for external-secrets chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"external-secrets","visibility":"private","description":"External Secrets Operator chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing External Secrets chart...$(RESET)"
	@helm package helm/charts/external-secrets -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/external-secrets/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/external-secrets-$$(grep '^version:' helm/charts/external-secrets/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,External Secrets chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/external-secrets)
