##@ Seed Secrets — AAP Manifest

.PHONY: aap-load-manifest
aap-load-manifest: check-env-central ## Base64-encode AAP manifest ZIP and write to Vault at central/aap-manifest
	@echo "$(BOLD)Loading AAP manifest from $$AAP_MANIFEST into Vault...$(RESET)"
	@if [ -z "$$AAP_MANIFEST" ]; then \
	  printf "  $(RED)✗$(RESET)  AAP_MANIFEST is not set\n"; \
	  exit 1; \
	fi; \
	if [ ! -f "$$AAP_MANIFEST" ]; then \
	  printf "  $(RED)✗$(RESET)  File not found: $$AAP_MANIFEST\n"; \
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
	MANIFEST_B64=$$(base64 -w 0 "$$AAP_MANIFEST"); \
	TMPFILE=$$(mktemp /tmp/aap-manifest-XXXXXX.json); \
	printf '{"data":{"manifest_b64":"%s"}}' "$$MANIFEST_B64" > "$$TMPFILE"; \
	HTTP_CODE=$$(curl -sk -o /dev/null -w "%{http_code}" \
	  -X POST "$$VAULT_ADDR/v1/central/data/aap-manifest" \
	  -H "X-Vault-Token: $$ROOT_TOKEN" \
	  -H "Content-Type: application/json" \
	  --data-binary "@$$TMPFILE"); \
	rm -f "$$TMPFILE"; \
	if echo "$$HTTP_CODE" | grep -qE '^2'; then \
	  printf "  $(GREEN)✓$(RESET)  AAP manifest written to Vault at central/aap-manifest\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Vault write failed (HTTP $$HTTP_CODE)\n"; \
	  exit 1; \
	fi
