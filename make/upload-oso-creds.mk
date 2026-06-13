##@ Seed Secrets — OpenStack Credentials

.PHONY: upload-oso-creds
upload-oso-creds: check-env-central ## Parse OSO_CLOUDS yaml and write credentials to Vault at central/openstack-credentials
	@echo "$(BOLD)Uploading OpenStack credentials from $$OSO_CLOUDS to Vault...$(RESET)"
	@if [ -z "$$OSO_CLOUDS" ]; then \
	  printf "  $(RED)✗$(RESET)  OSO_CLOUDS is not set\n"; \
	  exit 1; \
	fi; \
	if [ ! -f "$$OSO_CLOUDS" ]; then \
	  printf "  $(RED)✗$(RESET)  File not found: $$OSO_CLOUDS\n"; \
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
	OSO_JSON=$$(python3 -c " \
import yaml, json, sys; \
c = yaml.safe_load(open('$$OSO_CLOUDS')); \
clouds = c.get('clouds', {}); \
result = {}; \
for cn, cfg in clouds.items(): \
    a = cfg.get('auth', {}); \
    result['cloud_name'] = cn; \
    result['auth_url'] = a.get('auth_url', ''); \
    result['username'] = a.get('username', ''); \
    result['password'] = a.get('password', ''); \
    result['user_domain_name'] = a.get('user_domain_name', 'Default'); \
    result['project_name'] = a.get('project_name', '') if a.get('project_name') != 'None' else ''; \
    result['project_id'] = a.get('project_id', '') if a.get('project_id') != 'None' else ''; \
    result['region_name'] = cfg.get('region_name', ''); \
    break; \
print(json.dumps(result)); \
" 2>/dev/null); \
	if [ -z "$$OSO_JSON" ]; then \
	  printf "  $(RED)✗$(RESET)  Failed to parse OSO_CLOUDS file\n"; \
	  exit 1; \
	fi; \
	HTTP_CODE=$$(curl -sk -o /dev/null -w "%{http_code}" \
	  -X POST "$$VAULT_ADDR/v1/central/data/openstack-credentials" \
	  -H "X-Vault-Token: $$ROOT_TOKEN" \
	  -H "Content-Type: application/json" \
	  -d "{\"data\":$$OSO_JSON}"); \
	if echo "$$HTTP_CODE" | grep -qE '^2'; then \
	  printf "  $(GREEN)✓$(RESET)  OpenStack credentials written to Vault at central/openstack-credentials\n"; \
	else \
	  printf "  $(RED)✗$(RESET)  Vault write failed (HTTP $$HTTP_CODE)\n"; \
	  exit 1; \
	fi
