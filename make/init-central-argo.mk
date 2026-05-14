##@ Bootstrap Cluster

.PHONY: init-central-argo
init-central-argo: check-env ## Bootstrap ArgoCD on central cluster: install init chart and trigger app-of-apps
	@echo "$(BOLD)Logging in to services cluster to get SA token...$(RESET)"
	@oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1
	$(call ok,Logged in to services cluster)
	@echo "$(BOLD)Logging in to central cluster...$(RESET)"
	@SVC_TOKEN=$$(oc get secret argocd-manager-token -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null) && \
	oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1 && \
	echo "$(BOLD)Deploying bootstrap init chart...$(RESET)" && \
	helm upgrade --install sovereign-init helm/init \
	  --namespace openshift-gitops \
	  --create-namespace \
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
