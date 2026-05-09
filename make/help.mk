##@ Help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(BOLD)<target>$(RESET)\n"} \
	  /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-30s$(RESET) %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 5) }' $(MAKEFILE_LIST)
