##@ Build Artifacts

.PHONY: upload-sovereign-job-chart
upload-sovereign-job-chart: check-env ## Package and push sovereign-job chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for sovereign-job chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"sovereign-job","visibility":"private","description":"Generic sovereign Ansible job chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing sovereign-job chart...$(RESET)"
	@helm package helm/charts/sovereign-job -d /tmp/helm-pkg > /dev/null
	@helm push /tmp/helm-pkg/sovereign-job-$$(grep '^version:' helm/charts/sovereign-job/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,sovereign-job chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/sovereign-job)
