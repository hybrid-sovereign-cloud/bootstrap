##@ Check Bastion Configs

.PHONY: check-env
check-env: ## Verify all 12 required environment variables are set and test logins (OCP + OCI)
	@echo "$(BOLD)Checking required environment variables...$(RESET)"
	@missing=0; \
	for var in $(REQUIRED_VARS); do \
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
	else \
	  echo ""; \
	  echo "$(GREEN)All required variables are set.$(RESET)"; \
	fi
	@echo ""
	@echo "  Derived: OCI_HOST=$(OCI_HOST)  OCI_NAMESPACE=$(OCI_NAMESPACE)"
	@echo ""
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
	@echo "$(BOLD)Testing OCP services cluster login...$(RESET)"
	@if oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1; then \
	  printf "  $(GREEN)✓$(RESET)  Services cluster login successful\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Services cluster login FAILED\n"; \
	  exit 1; \
	fi
	@echo "$(BOLD)Testing OCI registry login...$(RESET)"
	@if helm registry login "$(OCI_HOST)" \
	  --username="$(OCI_ROBOT_USERNAME)" \
	  --password="$(OCI_ROBOT_PASSWORD)" 2>/dev/null; then \
	  printf "  $(GREEN)✓$(RESET)  OCI registry login successful\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  OCI registry login FAILED (host: $(OCI_HOST), user: $(OCI_ROBOT_USERNAME))\n"; \
	  exit 1; \
	fi
	@echo ""
	@echo "$(GREEN)All checks passed — environment is ready.$(RESET)"
