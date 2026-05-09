.PHONY: upload-external-secrets-chart
upload-external-secrets-chart: ## Package and push External Secrets chart to OCI registry
	@echo "── Packaging External Secrets chart ──"
	helm package helm/charts/external-secrets -d /tmp/charts/
	@echo "── Logging into OCI registry (admin) ──"
	helm registry login $(OCI_REGISTRY) -u '$$oauthtoken' -p $(OCI_REGISTRY_TOKEN)
	@echo "── Pushing External Secrets chart ──"
	helm push /tmp/charts/external-secrets-$$(grep '^version:' helm/charts/external-secrets/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_REGISTRY)/hybrid-sovereign
