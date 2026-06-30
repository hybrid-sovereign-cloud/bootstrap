##@ Seed Secrets — AAP Admin Credentials

.PHONY: aap-store-admin-central
aap-store-admin-central: check-env-central ## Read AAP controller admin password and store in Vault at central/aap-admin-central
	@echo "$(BOLD)Storing AAP central admin credentials in Vault...$(RESET)"
	@$(call sovereign_login_central)
	@VAULT_ADDR="https://vault-central.apps.shc-central.lab.signal9.gg"; \
	ROOT_TOKEN=$$(oc get secret vault-init-secrets -n central-vault \
	  -o jsonpath='{.data.root_token}' 2>/dev/null | base64 -d); \
	if [ -z "$$ROOT_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  vault-init-secrets not found — run after vaultInit job (wave 23) completes\n"; \
	  exit 1; \
	fi; \
	AAP_PASS=$$(oc get secret sovereign-aap-controller-admin-password -n aap \
	  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
	if [ -z "$$AAP_PASS" ]; then \
	  printf "  $(RED)✗$(RESET)  sovereign-aap-controller-admin-password not found — AAP not installed\n"; \
	  exit 1; \
	fi; \
	AAP_CTRL_URL="https://sovereign-aap-controller-aap.apps.shc-central.lab.signal9.gg"; \
	printf "  Getting AAP controller token...\n"; \
	AAP_TOKEN=$$(curl -sk -X POST "$$AAP_CTRL_URL/api/v2/tokens/" \
	  -u "admin:$$AAP_PASS" \
	  -H "Content-Type: application/json" \
	  -d '{"description":"sovereign-bootstrap","scope":"write"}' | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('token',''))" 2>/dev/null); \
	if [ -z "$$AAP_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  Failed to get AAP admin token — check AAP controller is running at $$AAP_CTRL_URL\n"; \
	  exit 1; \
	fi; \
	HTTP_CODE=$$(curl -sk -o /dev/null -w "%{http_code}" \
	  -X POST "$$VAULT_ADDR/v1/central/data/aap-admin-central" \
	  -H "X-Vault-Token: $$ROOT_TOKEN" \
	  -H "Content-Type: application/json" \
	  -d "{\"data\":{\"token\":\"$$AAP_TOKEN\",\"username\":\"admin\",\"password\":\"$$AAP_PASS\"}}"); \
	if echo "$$HTTP_CODE" | grep -qE '^2'; then \
	  printf "  $(GREEN)✓$(RESET)  AAP central admin credentials written to Vault at central/aap-admin-central\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Vault write failed (HTTP $$HTTP_CODE)\n"; \
	  exit 1; \
	fi

.PHONY: aap-store-admin-services
aap-store-admin-services: check-env-services ## Read AAP services admin password and store in Vault at central/aap-admin-services
	@echo "$(BOLD)Storing AAP services admin credentials in Vault...$(RESET)"
	@$(call sovereign_login_services)
	@VAULT_ADDR="https://vault-central.apps.shc-central.lab.signal9.gg"; \
	$(call sovereign_login_central); \
	ROOT_TOKEN=$$(oc get secret vault-init-secrets -n central-vault \
	  -o jsonpath='{.data.root_token}' 2>/dev/null | base64 -d); \
	if [ -z "$$ROOT_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  vault-init-secrets not found on central cluster\n"; \
	  exit 1; \
	fi; \
	$(call sovereign_login_services); \
	AAP_PASS=$$(oc get secret sovereign-aap-admin-password -n aap \
	  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
	if [ -z "$$AAP_PASS" ]; then \
	  printf "  $(RED)✗$(RESET)  sovereign-aap-admin-password not found in aap namespace\n"; \
	  exit 1; \
	fi; \
	CTRL_PASS=$$(oc get secret sovereign-aap-controller-admin-password -n aap \
	  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d); \
	if [ -z "$$CTRL_PASS" ]; then \
	  printf "  $(RED)✗$(RESET)  sovereign-aap-controller-admin-password not found in aap namespace\n"; \
	  exit 1; \
	fi; \
	AAP_CTRL_URL="https://sovereign-aap-controller-aap.apps.shcservices.lab.signal9.gg"; \
	printf "  Getting AAP services controller token...\n"; \
	AAP_TOKEN=$$(curl -sk -X POST "$$AAP_CTRL_URL/api/v2/tokens/" \
	  -u "admin:$$CTRL_PASS" \
	  -H "Content-Type: application/json" \
	  -d '{"description":"sovereign-bootstrap","scope":"write"}' | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('token',''))" 2>/dev/null); \
	if [ -z "$$AAP_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  Failed to get AAP services admin token — check AAP controller is running at $$AAP_CTRL_URL\n"; \
	  exit 1; \
	fi; \
	$(call sovereign_login_central); \
	HTTP_CODE=$$(curl -sk -o /dev/null -w "%{http_code}" \
	  -X POST "$$VAULT_ADDR/v1/central/data/aap-admin-services" \
	  -H "X-Vault-Token: $$ROOT_TOKEN" \
	  -H "Content-Type: application/json" \
	  -d "{\"data\":{\"token\":\"$$AAP_TOKEN\",\"username\":\"admin\",\"password\":\"$$AAP_PASS\"}}"); \
	if echo "$$HTTP_CODE" | grep -qE '^2'; then \
	  printf "  $(GREEN)✓$(RESET)  AAP services admin credentials written to Vault at central/aap-admin-services\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Vault write failed (HTTP $$HTTP_CODE)\n"; \
	  exit 1; \
	fi

