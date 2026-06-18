##@ Build Artifacts

.PHONY: upload-mtv-chart
upload-mtv-chart: check-env ## Package and push Migration Toolkit for Virtualization (MTV) chart to OCI registry
	@echo "$(BOLD)Ensuring repository for openshift-mtv chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"openshift-mtv","visibility":"private","description":"Migration Toolkit for Virtualization chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing openshift-mtv chart...$(RESET)"
	@helm package helm/charts/openshift-mtv -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/openshift-mtv/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/openshift-mtv-$$(grep '^version:' helm/charts/openshift-mtv/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,openshift-mtv chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/openshift-mtv)
