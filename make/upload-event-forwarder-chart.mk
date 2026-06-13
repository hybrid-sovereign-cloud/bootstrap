##@ Build Artifacts

.PHONY: upload-event-forwarder-chart
upload-event-forwarder-chart: check-env ## Package and push event-forwarder chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for event-forwarder chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"event-forwarder","visibility":"private","description":"Sovereign Cloud Event Forwarder chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing event-forwarder chart...$(RESET)"
	@helm package helm/charts/event-forwarder -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/event-forwarder/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/event-forwarder-$$(grep '^version:' helm/charts/event-forwarder/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,event-forwarder chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/event-forwarder)
