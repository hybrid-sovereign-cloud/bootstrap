PHONY: upload-team-operator-chart
upload-team-operator-chart: check-env ## Package and push team-operator chart to OCI registry
	@echo "$(BOLD)Packaging and pushing team-operator chart...$(RESET)"
	@cd ../$(shell echo "Team") && make upload-chart OCI_REGISTRY_HOST=$(OCI_HOST) OCI_REGISTRY_TOKEN=$(OCI_REGISTRY_TOKEN)
	$(call ok,team-operator chart pushed)
