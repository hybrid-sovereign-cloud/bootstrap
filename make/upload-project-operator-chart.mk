PHONY: upload-project-operator-chart
upload-project-operator-chart: check-env ## Package and push project-operator chart to OCI registry
	@echo "$(BOLD)Packaging and pushing project-operator chart...$(RESET)"
	@cd ../$(shell echo "Projects") && make upload-chart OCI_REGISTRY_HOST=$(OCI_HOST) OCI_REGISTRY_TOKEN=$(OCI_REGISTRY_TOKEN)
	$(call ok,project-operator chart pushed)
