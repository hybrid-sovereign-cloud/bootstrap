##@ Services Cluster ArgoCD SA

.PHONY: init-services-argocd-sa
init-services-argocd-sa: check-env ## Create ArgoCD manager SA + token on services cluster (pre-bootstrap)
	@echo "$(BOLD)Logging in to services cluster...$(RESET)"
	@oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1
	$(call ok,Logged in to services cluster)
	@echo "$(BOLD)Creating argocd-manager ServiceAccount...$(RESET)"
	@oc create serviceaccount argocd-manager -n kube-system 2>/dev/null || true
	$(call ok,ServiceAccount argocd-manager ensured)
	@echo "$(BOLD)Creating cluster-admin ClusterRoleBinding...$(RESET)"
	@oc create clusterrolebinding argocd-manager-cluster-role-binding \
	  --clusterrole=cluster-admin \
	  --serviceaccount=kube-system:argocd-manager 2>/dev/null || true
	$(call ok,ClusterRoleBinding ensured)
	@echo "$(BOLD)Creating SA token Secret...$(RESET)"
	@echo '{"apiVersion":"v1","kind":"Secret","metadata":{"name":"argocd-manager-token","namespace":"kube-system","annotations":{"kubernetes.io/service-account.name":"argocd-manager"}},"type":"kubernetes.io/service-account-token"}' | oc create -f - 2>/dev/null || true
	$(call ok,Token Secret ensured)
	@echo "$(BOLD)Waiting for token population...$(RESET)"
	@for i in $$(seq 1 30); do \
	  TOKEN=$$(oc get secret argocd-manager-token -n kube-system -o jsonpath='{.data.token}' 2>/dev/null); \
	  if [ -n "$$TOKEN" ] && [ "$$TOKEN" != "" ]; then \
	    echo "  $(GREEN)✓$(RESET)  Token populated"; \
	    break; \
	  fi; \
	  sleep 2; \
	done
	@echo "$(BOLD)Switching back to central cluster...$(RESET)"
	@oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1
	$(call ok,Switched to central cluster)
