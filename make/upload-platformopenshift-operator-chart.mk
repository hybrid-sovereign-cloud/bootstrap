PHONY: upload-platformopenshift-operator-chart
upload-platformopenshift-operator-chart: check-env ## Package and push platformopenshift-operator chart to OCI registry
	@echo "$(BOLD)Packaging and pushing platformopenshift-operator chart...$(RESET)"
	@cd ../$(shell echo "PlatformOpenshift") && make upload-chart OCI_REGISTRY_HOST=$(OCI_HOST) OCI_REGISTRY_TOKEN=$(OCI_REGISTRY_TOKEN)
	$(call ok,platformopenshift-operator chart pushed)
