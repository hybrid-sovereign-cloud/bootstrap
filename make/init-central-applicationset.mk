##@ Bootstrap Cluster — Layer 3: ApplicationSet

.PHONY: init-central-applicationset
init-central-applicationset: check-env init-services-argocd-sa ## Install ApplicationSet (central app-of-apps) — requires init-central-argo and init-central-secrets first
	@echo "$(BOLD)Fetching ArgoCD manager token from services cluster...$(RESET)"
	@SVC_TOKEN=$$(oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true >/dev/null 2>&1 && \
	  for i in $$(seq 1 30); do \
	    TOKEN=$$(oc get secret argocd-manager-token -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null); \
	    [ -n "$$TOKEN" ] && echo "$$TOKEN" && exit 0; \
	    sleep 2; \
	  done; \
	  exit 1) && \
	printf "  $(GREEN)✓$(RESET)  ArgoCD manager token retrieved\n" && \
	echo "$(BOLD)Logging in to central cluster...$(RESET)" && \
	$(call sovereign_login_central) && \
	if [ -z "$$SVC_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  argocd-manager token is empty — run: make init-services-argocd-sa\n"; \
	  exit 1; \
	fi && \
	if oc get namespace openshift-gitops-operator >/dev/null 2>&1; then \
	  if [ "$$(oc get namespace openshift-gitops-operator -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null)" != "Helm" ]; then \
	    oc label namespace openshift-gitops-operator app.kubernetes.io/managed-by=Helm --overwrite >/dev/null && \
	    oc annotate namespace openshift-gitops-operator \
	      meta.helm.sh/release-name=sovereign-init \
	      meta.helm.sh/release-namespace=openshift-gitops-operator --overwrite >/dev/null; \
	  fi; \
	fi && \
	echo "$(BOLD)Deploying ApplicationSet (all bootstrap layers)...$(RESET)" && \
	PUSH_SECRETS_FLAG="" && \
	if ! oc get crd pushsecrets.external-secrets.io >/dev/null 2>&1; then \
	  printf "  $(BOLD)~$(RESET)  ESO CRDs not installed yet — disabling PushSecrets for initial bootstrap\n"; \
	  PUSH_SECRETS_FLAG="--set pushSecrets.enabled=false"; \
	fi && \
	helm upgrade --install sovereign-init helm/init \
	  --namespace openshift-gitops-operator \
	  --create-namespace \
	  $(SOVEREIGN_INIT_BOOTSTRAP_APPSET) \
	  $$PUSH_SECRETS_FLAG \
	  $(SOVEREIGN_INIT_HELM_SECRETS_SETS) \
	  $(SOVEREIGN_INIT_HELM_APPSET_SETS) \
	  --wait --timeout=5m
	@printf "  $(GREEN)✓$(RESET)  ApplicationSet deployed — sovereign-central-apps will sync from Git\n"
