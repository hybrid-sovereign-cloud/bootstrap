##@ Build Artifacts

.PHONY: upload-aap-chart
upload-aap-chart: check-env ## Package and push AAP chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for aap chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"aap","visibility":"private","description":"Ansible Automation Platform chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing AAP chart...$(RESET)"
	@helm package helm/charts/aap -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/aap/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/aap-$$(grep '^version:' helm/charts/aap/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,AAP chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/aap)

.PHONY: upload-aap-instance-chart
upload-aap-instance-chart: check-env ## Package and push AAP-instance chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for aap-instance chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"aap-instance","visibility":"private","description":"AAP instance CR chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing AAP-instance chart...$(RESET)"
	@helm package helm/charts/aap-instance -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/aap-instance/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/aap-instance-$$(grep '^version:' helm/charts/aap-instance/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,AAP-instance chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/aap-instance)
