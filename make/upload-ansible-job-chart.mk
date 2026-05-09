.PHONY: upload-ansible-job-chart
upload-ansible-job-chart: ## Package and push Ansible Job chart to OCI registry
	@echo "── Packaging Ansible Job chart ──"
	helm package helm/charts/ansible-job -d /tmp/charts/
	@echo "── Logging into OCI registry (admin) ──"
	helm registry login $(OCI_REGISTRY) -u '$$oauthtoken' -p $(OCI_REGISTRY_TOKEN)
	@echo "── Pushing Ansible Job chart ──"
	helm push /tmp/charts/ansible-job-$$(grep '^version:' helm/charts/ansible-job/Chart.yaml | awk '{print $$2}').tgz oci://$(OCI_REGISTRY)/hybrid-sovereign
