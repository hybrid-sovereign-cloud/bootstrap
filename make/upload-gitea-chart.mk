##@ Build Artifacts

.PHONY: upload-gitea-chart
upload-gitea-chart: check-env ## Package and push Gitea chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for gitea chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"gitea","visibility":"private","description":"Gitea chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Building Gitea chart dependencies...$(RESET)"
	@helm dependency build helm/charts/gitea > /dev/null 2>&1
	$(call ok,Dependencies built)
	@echo "$(BOLD)Packaging and pushing Gitea chart...$(RESET)"
	@helm package helm/charts/gitea -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/gitea/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/gitea-$$(grep '^version:' helm/charts/gitea/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,Gitea chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/gitea)
