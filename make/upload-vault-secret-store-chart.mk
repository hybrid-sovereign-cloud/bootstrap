.PHONY: upload-vault-secret-store-chart
upload-vault-secret-store-chart: ## Package and push Vault SecretStore chart to OCI registry
	@echo "── Packaging Vault SecretStore chart ──"
	helm package helm/charts/vault-secret-store -d /tmp/charts/
	@echo "── Logging into OCI registry (admin) ──"
	helm registry login $(OCI_REGISTRY) -u '$$oauthtoken' -p $(OCI_REGISTRY_TOKEN)
	@echo "── Pushing Vault SecretStore chart ──"
	helm push /tmp/charts/vault-secret-store-$$(grep '^version:' helm/charts/vault-secret-store/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_REGISTRY)/hybrid-sovereign
