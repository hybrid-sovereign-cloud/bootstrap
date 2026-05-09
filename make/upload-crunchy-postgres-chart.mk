##@ Build Artifacts

.PHONY: upload-crunchy-postgres-chart
upload-crunchy-postgres-chart: check-env ## Package and push CrunchyData Postgres chart to OCI registry
	@echo "$(BOLD)Ensuring Quay repository for crunchy-postgres chart...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"crunchy-postgres","visibility":"private","description":"Crunchy Data PostgreSQL Operator chart","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to OCI registry...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | helm registry login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(OCI_HOST))
	@echo "$(BOLD)Packaging and pushing CrunchyData Postgres chart...$(RESET)"
	@helm package helm/charts/crunchy-postgres -d /tmp/helm-pkg --version $$(grep '^version:' helm/charts/crunchy-postgres/Chart.yaml | awk '{print $$2}') > /dev/null
	@helm push /tmp/helm-pkg/crunchy-postgres-$$(grep '^version:' helm/charts/crunchy-postgres/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_HOST)/$(OCI_NAMESPACE)
	$(call ok,CrunchyData Postgres chart pushed to oci://$(OCI_HOST)/$(OCI_NAMESPACE)/crunchy-postgres)
