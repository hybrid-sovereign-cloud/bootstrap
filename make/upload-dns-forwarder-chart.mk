##@ Build Artifacts

.PHONY: upload-dns-forwarder-chart
upload-dns-forwarder-chart: check-env ## Package and push DNS forwarder chart to OCI registry
	@echo "$(BOLD)Ensuring repository for dns-forwarder chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"dns-forwarder","visibility":"private","description":"OpenShift CoreDNS lab forwarder chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing dns-forwarder chart...$(RESET)"
	@helm package helm/charts/dns-forwarder -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/dns-forwarder/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/dns-forwarder-$$(grep '^version:' helm/charts/dns-forwarder/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,dns-forwarder chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/dns-forwarder)
