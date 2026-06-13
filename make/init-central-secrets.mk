##@ Bootstrap Cluster — Layer 2: Secrets

.PHONY: init-central-secrets
init-central-secrets: check-env init-services-argocd-sa ## Seed bootstrap secrets (repo, cluster, OCI, pull, Gitea) via sovereign-init chart
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
	INSTALL_OPERATOR_FLAG="" && \
	if ! oc get subscriptions.operators.coreos.com/openshift-gitops-operator -n openshift-gitops-operator >/dev/null 2>&1; then \
	  EXISTING_CSV=$$(oc get csv -A -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift GitOps")].metadata.name}' 2>/dev/null | tr ' ' '\n' | head -1); \
	  [ -n "$$EXISTING_CSV" ] && INSTALL_OPERATOR_FLAG="--set gitopsOperator.installOperator=false"; \
	fi && \
	echo "$(BOLD)Deploying bootstrap secrets (bootstrap.operator + bootstrap.secrets)...$(RESET)" && \
	oc create namespace argocd-schema-fix 2>/dev/null || true && \
	APPSET_FLAG="" && \
	if oc get applicationsets.argoproj.io sovereign-bootstrap -n openshift-gitops >/dev/null 2>&1; then \
	  APPSET_FLAG="--set bootstrap.applicationset=true"; \
	fi && \
	PUSH_SECRETS_FLAG="" && \
	if ! oc get crd pushsecrets.external-secrets.io >/dev/null 2>&1; then \
	  printf "  $(BOLD)~$(RESET)  ESO CRDs not installed yet — disabling PushSecrets for initial bootstrap\n"; \
	  PUSH_SECRETS_FLAG="--set pushSecrets.enabled=false"; \
	fi && \
	helm upgrade --install sovereign-init helm/init \
	  --namespace openshift-gitops-operator \
	  --create-namespace \
	  $(SOVEREIGN_INIT_BOOTSTRAP_SECRETS) \
	  $$APPSET_FLAG \
	  $$PUSH_SECRETS_FLAG \
	  $(SOVEREIGN_INIT_HELM_SECRETS_SETS) \
	  $$INSTALL_OPERATOR_FLAG \
	  --wait --timeout=5m && \
	printf "  $(GREEN)✓$(RESET)  Bootstrap secrets deployed — next: make init-central-applicationset\n"
