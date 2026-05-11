PHONY: upload-cloudoso-operator-chart
upload-cloudoso-operator-chart: check-env ## Package and push cloudoso-operator chart to OCI registry
	@echo "$(BOLD)Packaging and pushing cloudoso-operator chart...$(RESET)"
	@cd ../$(shell echo "CloudOSO") && make upload-chart OCI_REGISTRY_HOST=$(OCI_HOST) OCI_REGISTRY_TOKEN=$(OCI_REGISTRY_TOKEN)
	$(call ok,cloudoso-operator chart pushed)
