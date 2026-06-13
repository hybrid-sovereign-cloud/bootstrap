##@ Check Bastion Configs

.PHONY: check-env
check-env: ## Verify all required environment variables are set and test logins (OCP + OCI)
	@failures=0; \
	\
	echo "$(BOLD)Checking required environment variables...$(RESET)"; \
	missing=0; \
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
	  printf "  $(RED)✗$(RESET)  $$missing required variable(s) missing\n"; \
	  failures=$$((failures+1)); \
	else \
	  echo ""; \
	  printf "  $(GREEN)✓$(RESET)  All required variables are set\n"; \
	fi; \
	\
	echo ""; \
	echo "  Derived: OCI_HOST=$(OCI_HOST)  OCI_NAMESPACE=$(OCI_NAMESPACE)"; \
	echo ""; \
	\
	echo "$(BOLD)Testing OCP central cluster login...$(RESET)"; \
	if oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1; then \
	  printf "  $(GREEN)✓$(RESET)  Central cluster login successful\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Central cluster login FAILED\n"; \
	  failures=$$((failures+1)); \
	fi; \
	\
	echo "$(BOLD)Testing OCP services cluster login...$(RESET)"; \
	if oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1; then \
	  printf "  $(GREEN)✓$(RESET)  Services cluster login successful\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Services cluster login FAILED\n"; \
	  failures=$$((failures+1)); \
	fi; \
	\
	echo "$(BOLD)Testing OCI registry login...$(RESET)"; \
	if helm registry login "$(OCI_HOST)" \
	  --username="$(OCI_ROBOT_USERNAME)" \
	  --password="$(OCI_ROBOT_PASSWORD)" 2>/dev/null; then \
	  printf "  $(GREEN)✓$(RESET)  OCI registry login successful\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  OCI registry login FAILED (host: $(OCI_HOST), user: $(OCI_ROBOT_USERNAME))\n"; \
	  failures=$$((failures+1)); \
	fi; \
	\
	echo "$(BOLD)Testing OpenStack credentials...$(RESET)"; \
	if command -v openstack >/dev/null 2>&1; then \
	  if [ ! -f "$(OSO_CLOUDS)" ]; then \
	    printf "  $(RED)✗$(RESET)  OSO_CLOUDS file not found: $(OSO_CLOUDS)\n"; \
	    failures=$$((failures+1)); \
	  else \
	    oso_result=$$(python3 -c "\
import yaml,subprocess,os,sys; \
c=yaml.safe_load(open('$(OSO_CLOUDS)')); \
cn=list(c.get('clouds',{}).keys())[0]; \
a=c['clouds'][cn].get('auth',{}); \
env={**os.environ,'OS_AUTH_URL':a.get('auth_url',''),'OS_USERNAME':a.get('username',''),'OS_PASSWORD':a.get('password',''),'OS_USER_DOMAIN_NAME':a.get('user_domain_name','Default'),'OS_PROJECT_ID':'','OS_PROJECT_NAME':'','OS_CLOUD':''}; \
r=subprocess.run(['openstack','token','issue','-f','value','-c','id'],env=env,capture_output=True,text=True); \
print(cn+'|'+str(r.returncode)) \
" 2>/dev/null); \
	    oso_cloud_name=$$(echo "$$oso_result" | cut -d'|' -f1); \
	    oso_rc=$$(echo "$$oso_result" | cut -d'|' -f2); \
	    if [ "$$oso_rc" = "0" ]; then \
	      printf "  $(GREEN)✓$(RESET)  OpenStack token issued successfully (cloud: $$oso_cloud_name, file: $(OSO_CLOUDS))\n"; \
	    else \
	      printf "  $(RED)✗$(RESET)  OpenStack auth FAILED (cloud: $$oso_cloud_name, file: $(OSO_CLOUDS))\n"; \
	      failures=$$((failures+1)); \
	    fi; \
	  fi; \
	else \
	  printf "  $(BOLD)~$(RESET)  openstack CLI not found — skipping live auth check (OSO_CLOUDS=$(OSO_CLOUDS))\n"; \
	fi; \
	\
	echo "$(BOLD)Testing AWS credentials...$(RESET)"; \
	if command -v aws >/dev/null 2>&1; then \
	  if aws sts get-caller-identity --output text --query 'Account' 2>/dev/null | grep -qF "$(AWS_ACCOUNT_ID)"; then \
	    printf "  $(GREEN)✓$(RESET)  AWS credentials valid (account: $(AWS_ACCOUNT_ID))\n"; \
	  else \
	    printf "  $(RED)✗$(RESET)  AWS auth FAILED — sts:GetCallerIdentity returned unexpected account (expected: $(AWS_ACCOUNT_ID))\n"; \
	    failures=$$((failures+1)); \
	  fi; \
	else \
	  printf "  $(BOLD)~$(RESET)  aws CLI not found — skipping live auth check (account: $(AWS_ACCOUNT_ID))\n"; \
	fi; \
	\
	echo ""; \
	if [ $$failures -gt 0 ]; then \
	  echo "$(RED)$$failures check(s) failed — fix the issues above and re-run make check-env.$(RESET)"; \
	  exit 1; \
	else \
	  echo "$(GREEN)All checks passed — environment is ready.$(RESET)"; \
	fi
