PHONY: upload-openstackmigration-operator-chart
upload-openstackmigration-operator-chart: check-env ## Package and push openstackmigration-operator chart to OCI registry
	@echo "$(BOLD)Packaging and pushing openstackmigration-operator chart...$(RESET)"
	@cd ../$(shell echo "OpenStackMigration") && make upload-chart OCI_REGISTRY_HOST=$(OCI_HOST) OCI_REGISTRY_TOKEN=$(OCI_REGISTRY_TOKEN)
	$(call ok,openstackmigration-operator chart pushed)
