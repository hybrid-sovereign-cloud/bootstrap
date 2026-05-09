##@ Bootstrap Cluster

.PHONY: init-central-argo
init-central-argo: check-env ## Bootstrap ArgoCD on central cluster: install init chart and trigger app-of-apps
	@echo "$(BOLD)Logging in to central cluster...$(RESET)"
	@oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true
	$(call ok,Logged in to central cluster)
	@echo "$(BOLD)Deploying bootstrap init chart...$(RESET)"
	@helm upgrade --install sovereign-init helm/init \
	  --namespace openshift-gitops \
	  --create-namespace \
	  --set gitops.repoURL="$(GITHUB_URL)" \
	  --set gitops.token="$(GITHUB_TOKEN)" \
	  --set clusters.services.server="$(OCP_SERVICES_SERVER)" \
	  --set clusters.services.username="$(OCP_SERVICES_USERNAME)" \
	  --set clusters.services.password="$(OCP_SERVICES_PASSWORD)" \
	  --set clusters.services.tlsSkipVerify=true \
	  --set oci.registry="$(OCI_HOST)" \
	  --set oci.namespace="$(OCI_NAMESPACE)" \
	  --set oci.robotUsername="$(OCI_ROBOT_USERNAME)" \
	  --set oci.robotPassword="$(OCI_ROBOT_PASSWORD)" \
	  --wait --timeout=5m
	$(call ok,sovereign-init deployed — ApplicationSet and app-of-apps triggered)
