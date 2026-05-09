##@ Check Bastion Configs

.PHONY: add-docker-repo
add-docker-repo: check-env ## Trust IMAGE_REGISTRY on both clusters (creates pull secret)
	@echo "$(BOLD)Adding image registry pull secret to central cluster...$(RESET)"
	@oc login "$(OCP_CENTRAL_SERVER)" \
	  --username="$(OCP_CENTRAL_USERNAME)" \
	  --password="$(OCP_CENTRAL_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1
	@oc get secret image-registry-pull -n openshift-config > /dev/null 2>&1 && \
	  oc delete secret image-registry-pull -n openshift-config > /dev/null 2>&1 || true
	@oc create secret docker-registry image-registry-pull \
	  --docker-server="$(IMAGE_REGISTRY)" \
	  --docker-username="$(IMAGE_REGISTRY_USERNAME)" \
	  --docker-password="$(IMAGE_REGISTRY_PASSWORD)" \
	  -n openshift-config > /dev/null 2>&1
	@oc patch image.config.openshift.io/cluster --type=merge \
	  -p '{"spec":{"registrySources":{"allowedRegistries":["$(IMAGE_REGISTRY)","quay.io","$(OCI_HOST)","registry.redhat.io","registry.access.redhat.com","image-registry.openshift-image-registry.svc:5000"]}}}' > /dev/null 2>&1 || true
	$(call ok,Image registry configured on central cluster)
	@echo "$(BOLD)Adding image registry pull secret to services cluster...$(RESET)"
	@oc login "$(OCP_SERVICES_SERVER)" \
	  --username="$(OCP_SERVICES_USERNAME)" \
	  --password="$(OCP_SERVICES_PASSWORD)" \
	  --insecure-skip-tls-verify=true > /dev/null 2>&1
	@oc get secret image-registry-pull -n openshift-config > /dev/null 2>&1 && \
	  oc delete secret image-registry-pull -n openshift-config > /dev/null 2>&1 || true
	@oc create secret docker-registry image-registry-pull \
	  --docker-server="$(IMAGE_REGISTRY)" \
	  --docker-username="$(IMAGE_REGISTRY_USERNAME)" \
	  --docker-password="$(IMAGE_REGISTRY_PASSWORD)" \
	  -n openshift-config > /dev/null 2>&1
	@oc patch image.config.openshift.io/cluster --type=merge \
	  -p '{"spec":{"registrySources":{"allowedRegistries":["$(IMAGE_REGISTRY)","quay.io","$(OCI_HOST)","registry.redhat.io","registry.access.redhat.com","image-registry.openshift-image-registry.svc:5000"]}}}' > /dev/null 2>&1 || true
	$(call ok,Image registry configured on services cluster)
