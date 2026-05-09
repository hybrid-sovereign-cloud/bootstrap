.PHONY: upload-gitea-chart
upload-gitea-chart: ## Package and push Gitea chart to OCI registry
	@echo "── Building Gitea chart dependencies ──"
	helm dependency build helm/charts/gitea
	@echo "── Packaging Gitea chart ──"
	helm package helm/charts/gitea -d /tmp/charts/
	@echo "── Logging into OCI registry (admin) ──"
	helm registry login $(OCI_REGISTRY) -u '$$oauthtoken' -p $(OCI_REGISTRY_TOKEN)
	@echo "── Pushing Gitea chart ──"
	helm push /tmp/charts/gitea-$$(grep '^version:' helm/charts/gitea/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_REGISTRY)/hybrid-sovereign
