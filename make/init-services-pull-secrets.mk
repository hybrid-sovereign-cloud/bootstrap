##@ Services Cluster Pull Secrets

.PHONY: init-services-pull-secrets
init-services-pull-secrets: check-env ## Create OCI pull secrets on services cluster for sovereign namespaces
	@echo "$(BOLD)Logging in to services cluster...$(RESET)"
	@oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true
	$(call ok,Logged in to services cluster)
	@for ns in sovereign-cloud sovereign-cloud-plugins; do \
	  echo "$(BOLD)Creating quay-pull-secret in $$ns...$(RESET)"; \
	  oc create secret docker-registry quay-pull-secret \
	    --namespace="$$ns" \
	    --docker-server="$(OCI_HOST)" \
	    --docker-username="$(OCI_ROBOT_USERNAME)" \
	    --docker-password="$(OCI_ROBOT_PASSWORD)" \
	    --dry-run=client -o yaml | oc apply -f - ; \
	  echo "  ✓  quay-pull-secret created in $$ns"; \
	done
	$(call ok,Pull secrets created on services cluster)
	@echo "$(BOLD)Switching back to central cluster...$(RESET)"
	@oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true
	$(call ok,Switched back to central cluster)
