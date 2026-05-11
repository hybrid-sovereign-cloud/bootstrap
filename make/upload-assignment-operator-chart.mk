PHONY: upload-assignment-operator-chart
upload-assignment-operator-chart: check-env ## Package and push assignment-operator chart to OCI registry
	@echo "$(BOLD)Packaging and pushing assignment-operator chart...$(RESET)"
	@cd ../$(shell echo "Assignment") && make upload-chart OCI_REGISTRY_HOST=$(OCI_HOST) OCI_REGISTRY_TOKEN=$(OCI_REGISTRY_TOKEN)
	$(call ok,assignment-operator chart pushed)
