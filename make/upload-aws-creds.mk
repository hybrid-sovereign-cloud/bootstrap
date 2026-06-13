##@ Seed Secrets — AWS Credentials

.PHONY: upload-aws-creds
upload-aws-creds: check-env-central ## Write AWS credentials to Vault at central/aws-credentials
	@echo "$(BOLD)Uploading AWS credentials to Vault...$(RESET)"
	@if [ -z "$(AWS_ACCESS_KEY_ID)" ] || [ -z "$(AWS_SECRET_ACCESS_KEY)" ] || [ -z "$(AWS_ACCOUNT_ID)" ]; then \
	  printf "  $(RED)✗$(RESET)  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_ACCOUNT_ID must be set\n"; \
	  exit 1; \
	fi
	@$(call sovereign_login_central)
	@VAULT_ADDR="https://vault-central.apps.shc-central.lab.signal9.gg"; \
	ROOT_TOKEN=$$(oc get secret vault-init-secrets -n central-vault \
	  -o jsonpath='{.data.root_token}' 2>/dev/null | base64 -d); \
	if [ -z "$$ROOT_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  vault-init-secrets not found — run after vaultInit job (wave 23) completes\n"; \
	  exit 1; \
	fi; \
	HTTP_CODE=$$(curl -sk -o /dev/null -w "%{http_code}" \
	  -X POST "$$VAULT_ADDR/v1/central/data/aws-credentials" \
	  -H "X-Vault-Token: $$ROOT_TOKEN" \
	  -H "Content-Type: application/json" \
	  -d "{\"data\":{\"access_key_id\":\"$(AWS_ACCESS_KEY_ID)\",\"secret_access_key\":\"$(AWS_SECRET_ACCESS_KEY)\",\"account_id\":\"$(AWS_ACCOUNT_ID)\"}}"); \
	if echo "$$HTTP_CODE" | grep -qE '^2'; then \
	  printf "  $(GREEN)✓$(RESET)  AWS credentials written to Vault at central/aws-credentials\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Vault write failed (HTTP $$HTTP_CODE)\n"; \
	  exit 1; \
	fi
