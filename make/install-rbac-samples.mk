##@ RBAC Samples

# Paths to sample directories
PLUGIN_RBAC_SAMPLES := ../plugin_rbac/config/samples
TEAM_SAMPLES := ../Team/config/samples
PROJECTS_SAMPLES := ../Projects/config/samples
ASSIGNMENT_SAMPLES := ../Assignment/config/samples
PLUGIN_VAULT_SAMPLES := ../plugin_vault/config/samples
PLUGIN_QUAY_SAMPLES := ../plugin_quay/config/samples
PLUGIN_AAP_SAMPLES := ../plugin_aap/config/samples

# Entity namespace for all samples
ENTITY_NS := entity-acme-corp

.PHONY: install-rbac-samples
install-rbac-samples: check-env ## Install all RBAC samples: Rbac CRs, Teams, Projects, Assignments, VaultKV, QuayOrg, AAPOrg
	@echo "$(BOLD)Installing RBAC CRs (Keycloak groups)...$(RESET)"
	@oc apply -f $(PLUGIN_RBAC_SAMPLES)/ -n $(ENTITY_NS) \
	  --server="$(OCP_SERVICES_SERVER)" \
	  --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true
	$(call ok,Rbac CRs applied)

	@echo "$(BOLD)Waiting for Rbac CRs to be ready (up to 120s)...$(RESET)"
	@timeout 120 bash -c 'until oc get rbacs -n $(ENTITY_NS) \
	  --server="$(OCP_SERVICES_SERVER)" --insecure-skip-tls-verify=true \
	  -o jsonpath="{.items[?(@.status.ready==false)].metadata.name}" 2>/dev/null | grep -q "."; \
	  do sleep 5; done; sleep 5' || true
	$(call ok,Rbac CRs ready)

	@echo "$(BOLD)Installing Teams...$(RESET)"
	@for f in $(TEAM_SAMPLES)/team-*.yaml; do \
	  oc apply -f $$f -n $(ENTITY_NS) \
	    --server="$(OCP_SERVICES_SERVER)" \
	    --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true; \
	done
	$(call ok,Teams applied)

	@echo "$(BOLD)Installing Projects...$(RESET)"
	@for f in $(PROJECTS_SAMPLES)/project-*.yaml; do \
	  oc apply -f $$f -n $(ENTITY_NS) \
	    --server="$(OCP_SERVICES_SERVER)" \
	    --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true; \
	done
	$(call ok,Projects applied)

	@echo "$(BOLD)Installing VaultKV instances...$(RESET)"
	@for f in $(PLUGIN_VAULT_SAMPLES)/vaultkv-acme-*.yaml; do \
	  oc apply -f $$f -n $(ENTITY_NS) \
	    --server="$(OCP_SERVICES_SERVER)" \
	    --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true; \
	done
	$(call ok,VaultKV instances applied)

	@echo "$(BOLD)Installing QuayOrg instances...$(RESET)"
	@for f in $(PLUGIN_QUAY_SAMPLES)/quayorg-acme-*.yaml; do \
	  oc apply -f $$f -n $(ENTITY_NS) \
	    --server="$(OCP_SERVICES_SERVER)" \
	    --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true; \
	done
	$(call ok,QuayOrg instances applied)

	@echo "$(BOLD)Installing AAPOrg instances...$(RESET)"
	@for f in $(PLUGIN_AAP_SAMPLES)/aaporg-acme-*.yaml; do \
	  oc apply -f $$f -n $(ENTITY_NS) \
	    --server="$(OCP_SERVICES_SERVER)" \
	    --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true; \
	done
	$(call ok,AAPOrg instances applied)

	@echo "$(BOLD)Installing Assignments...$(RESET)"
	@for f in $(ASSIGNMENT_SAMPLES)/assignment-ses*.yaml $(ASSIGNMENT_SAMPLES)/assignment-ses5-*.yaml; do \
	  [ -f "$$f" ] && oc apply -f $$f -n $(ENTITY_NS) \
	    --server="$(OCP_SERVICES_SERVER)" \
	    --insecure-skip-tls-verify=true 2>&1 | grep -v "unchanged" || true; \
	done
	$(call ok,Assignments applied)

	@echo ""
	@echo "$(BOLD)$(GREEN)RBAC samples installation complete.$(RESET)"
	@echo "Monitor CR readiness with:"
	@echo "  oc get rbacs,teams,projects,assignments,vaultkvs,quayorgs,aaporgs -n $(ENTITY_NS)"

.PHONY: delete-rbac-samples
delete-rbac-samples: check-env ## Delete all RBAC samples (Assignments, VaultKV, QuayOrg, AAPOrg, Teams, Projects, Rbac CRs)
	@echo "$(BOLD)$(RED)WARNING: Deleting all RBAC samples from $(ENTITY_NS)$(RESET)"
	@echo "$(BOLD)Deleting Assignments...$(RESET)"
	@oc delete assignments -n $(ENTITY_NS) \
	  -l entity=acme-corp \
	  --server="$(OCP_SERVICES_SERVER)" \
	  --insecure-skip-tls-verify=true 2>&1 || true
	$(call ok,Assignments deleted)

	@echo "$(BOLD)Deleting VaultKV, QuayOrg, AAPOrg...$(RESET)"
	@oc delete vaultkvs quayorgs aaporgs -n $(ENTITY_NS) \
	  --all \
	  --server="$(OCP_SERVICES_SERVER)" \
	  --insecure-skip-tls-verify=true 2>&1 || true
	$(call ok,Plugin resources deleted)

	@echo "$(BOLD)Deleting Teams and Projects...$(RESET)"
	@oc delete teams projects -n $(ENTITY_NS) \
	  --all \
	  --server="$(OCP_SERVICES_SERVER)" \
	  --insecure-skip-tls-verify=true 2>&1 || true
	$(call ok,Teams and Projects deleted)

	@echo "$(BOLD)Deleting Rbac CRs...$(RESET)"
	@oc delete rbacs -n $(ENTITY_NS) \
	  --all \
	  --server="$(OCP_SERVICES_SERVER)" \
	  --insecure-skip-tls-verify=true 2>&1 || true
	$(call ok,Rbac CRs deleted)

	$(call ok,RBAC samples deleted)
