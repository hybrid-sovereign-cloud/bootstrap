##@ Check Bastion Configs — Central Cluster Only

CENTRAL_REQUIRED_VARS := OCP_CENTRAL_SERVER OCP_CENTRAL_USERNAME OCP_CENTRAL_PASSWORD

.PHONY: check-env-central
check-env-central: ## Verify central cluster env vars and login (layer 1 bootstrap only)
	@echo "$(BOLD)Checking central cluster environment variables...$(RESET)"
	@missing=0; \
	for var in $(CENTRAL_REQUIRED_VARS); do \
	  val=$$(eval echo \$${$$var}); \
	  if [ -z "$$val" ]; then \
	    printf "  $(RED)✗$(RESET)  $$var is not set\n"; \
	    missing=$$((missing+1)); \
	  else \
	    printf "  $(GREEN)✓$(RESET)  $$var\n"; \
	  fi; \
	done; \
	if [ $$missing -gt 0 ]; then \
	  echo ""; \
	  echo "$(RED)ERROR$(RESET): $$missing required variable(s) missing. Export them and retry."; \
	  exit 1; \
	fi
	@echo "$(BOLD)Testing OCP central cluster login...$(RESET)"
	@if oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1; then \
	  printf "  $(GREEN)✓$(RESET)  Central cluster login successful\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Central cluster login FAILED\n"; \
	  exit 1; \
	fi
	$(call ok,Central cluster environment ready)
