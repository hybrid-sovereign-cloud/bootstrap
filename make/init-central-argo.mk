##@ Bootstrap Cluster

.PHONY: init-central-argo
init-central-argo: check-env init-services-argocd-sa init-services-pull-secrets ## Bootstrap ArgoCD on central cluster: install GitOps operator, ArgoCD, init chart, app-of-apps
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
	$(call ok,ArgoCD manager token retrieved) && \
	echo "$(BOLD)Logging in to central cluster...$(RESET)" && \
	oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1 && \
	if [ -z "$$SVC_TOKEN" ]; then \
	  printf "  $(RED)✗$(RESET)  argocd-manager token is empty — run: make init-services-argocd-sa\n"; \
	  exit 1; \
	fi && \
	echo "$(BOLD)Phase 1: Installing OpenShift GitOps operator...$(RESET)" && \
	if [ "$$(oc get namespace openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null)" = "Terminating" ]; then \
	  echo "  Waiting for openshift-gitops namespace to finish terminating..."; \
	  WAIT=0; \
	  while oc get namespace openshift-gitops >/dev/null 2>&1; do \
	    if [ $$WAIT -ge 60 ] && oc get argocd openshift-gitops -n openshift-gitops >/dev/null 2>&1; then \
	      echo "  Clearing ArgoCD finalizer (GitopsService-managed instance)..."; \
	      oc patch argocd openshift-gitops -n openshift-gitops --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null; \
	    fi; \
	    sleep 5; \
	    WAIT=$$((WAIT + 5)); \
	  done; \
	fi && \
	oc create namespace openshift-gitops-operator --dry-run=client -o yaml | oc apply -f - > /dev/null && \
	helm upgrade --install sovereign-init helm/init \
	  --namespace openshift-gitops-operator \
	  --set bootstrapPhase=operator \
	  --wait --timeout=5m && \
	echo "$(BOLD)Waiting for OpenShift GitOps operator CSV...$(RESET)" && \
	CSV="" && \
	for i in $$(seq 1 60); do \
	  CSV=$$(oc get subscription openshift-gitops-operator -n openshift-gitops-operator -o jsonpath='{.status.installedCSV}' 2>/dev/null); \
	  [ -n "$$CSV" ] && break; \
	  sleep 5; \
	done && \
	if [ -z "$$CSV" ]; then \
	  printf "  $(RED)✗$(RESET)  openshift-gitops-operator subscription has no installedCSV after 5 minutes\n"; \
	  exit 1; \
	fi && \
	oc wait --for=jsonpath='{.status.phase}'=Succeeded "csv/$$CSV" -n openshift-gitops-operator --timeout=15m && \
	$(call ok_print,OpenShift GitOps operator ready: $$CSV) && \
	echo "$(BOLD)Waiting for GitopsService to create openshift-gitops namespace...$(RESET)" && \
	for i in $$(seq 1 60); do \
	  if [ "$$(oc get namespace openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null)" = "Active" ]; then break; fi; \
	  sleep 5; \
	done && \
	if [ "$$(oc get namespace openshift-gitops -o jsonpath='{.status.phase}' 2>/dev/null)" != "Active" ]; then \
	  printf "  $(RED)✗$(RESET)  openshift-gitops namespace not Active after 5 minutes\n"; \
	  exit 1; \
	fi && \
	echo "$(BOLD)Waiting for Argo CD server...$(RESET)" && \
	oc wait --for=condition=Available deployment/openshift-gitops-server -n openshift-gitops --timeout=15m && \
	$(call ok_print,Argo CD server available) && \
	echo "$(BOLD)Configuring Argo CD sync timeout (10m) and retries...$(RESET)" && \
	oc patch argocd openshift-gitops -n openshift-gitops --type=merge \
	  -p '{"spec":{"cmdParams":{"controller.sync.timeout.seconds":"600"}}}' > /dev/null && \
	oc rollout status statefulset/openshift-gitops-application-controller -n openshift-gitops --timeout=5m > /dev/null && \
	$(call ok_print,Argo CD sync timeout set to 600s) && \
	echo "$(BOLD)Phase 2: Deploying sovereign-init (secrets + ApplicationSet)...$(RESET)" && \
	helm upgrade --install sovereign-init helm/init \
	  --namespace openshift-gitops-operator \
	  --set bootstrapPhase=full \
	  --set gitops.repoURL="$(GITHUB_URL)" \
	  --set gitops.token="$(GITHUB_TOKEN)" \
	  --set clusters.services.server="$(OCP_SERVICES_SERVER)" \
	  --set clusters.services.bearerToken="$$SVC_TOKEN" \
	  --set clusters.services.tlsSkipVerify=true \
	  --set oci.registry="$(OCI_HOST)" \
	  --set oci.namespace="$(OCI_NAMESPACE)" \
	  --set oci.robotUsername="$(OCI_ROBOT_USERNAME)" \
	  --set oci.robotPassword="$(OCI_ROBOT_PASSWORD)" \
	  --set gitea.adminPassword="$(GITEA_ADMIN_PASSWORD)" \
	  --wait --timeout=5m
	$(call ok,sovereign-init deployed — ApplicationSet and app-of-apps triggered)
