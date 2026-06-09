##@ Services Cluster Pull Secrets

.PHONY: init-services-pull-secrets
init-services-pull-secrets: check-env ## Create OCI pull secrets on services cluster for sovereign namespaces
	@echo "$(BOLD)Logging in to services cluster...$(RESET)"
	@oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true
	$(call ok,Logged in to services cluster)
	@failed=0; \
	for ns in sovereign-cloud sovereign-cloud-plugins vault rhbk external-secrets gitea sovereign-cloud-jobs sovereign-cloud-helpers; do \
	  echo "$(BOLD)Creating quay-pull-secret in $$ns...$(RESET)"; \
	  if ! oc get namespace "$$ns" >/dev/null 2>&1; then \
	    printf "  $(RED)✗$(RESET)  namespace $$ns does not exist — skip (run after sovereign-namespaces is deployed)\n"; \
	    failed=$$((failed+1)); \
	    continue; \
	  fi; \
	  if oc create secret docker-registry quay-pull-secret \
	    --namespace="$$ns" \
	    --docker-server="$(OCI_HOST)" \
	    --docker-username="$(OCI_ROBOT_USERNAME)" \
	    --docker-password="$(OCI_ROBOT_PASSWORD)" \
	    --dry-run=client -o yaml | oc apply -f - ; then \
	    printf "  $(GREEN)✓$(RESET)  quay-pull-secret created in $$ns\n"; \
	  else \
	    printf "  $(RED)✗$(RESET)  failed to create quay-pull-secret in $$ns\n"; \
	    failed=$$((failed+1)); \
	  fi; \
	done; \
	if [ $$failed -gt 0 ]; then \
	  echo ""; \
	  echo "$(RED)ERROR$(RESET): $$failed namespace(s) missing or failed. Deploy sovereign-namespaces on services first, or rely on init-central-secrets pull-secrets on central."; \
	  exit 1; \
	fi
	$(call ok,Pull secrets created on services cluster)
	@echo "$(BOLD)Switching back to central cluster...$(RESET)"
	@oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true
	$(call ok,Switched back to central cluster)
