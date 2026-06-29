##@ Local Ansible Iteration

.PHONY: run-eda-config-local
run-eda-config-local: check-env-central ## Run eda-config.yml locally against central cluster (fast iteration)
	@echo "$(BOLD)Logging in to central cluster...$(RESET)"
	@$(call sovereign_login_central)
	$(call ok,Logged in to central cluster)
	@echo "$(BOLD)Fetching job secrets from cluster...$(RESET)"
	@export EDA_CONTROLLER_URL="https://sovereign-aap-aap.apps.shc-central.lab.signal9.gg" && \
	export AAP_CONTROLLER_URL="$$EDA_CONTROLLER_URL" && \
	export AAP_RESOURCE_TOKEN=$$(oc get secret eda-admin-credentials -n sovereign-cloud-jobs -o jsonpath='{.data.token}' | base64 -d) && \
	export RULEBOOK_REPO_URL="https://github.com/hybrid-sovereign-cloud/eda.git" && \
	export GITHUB_TOKEN=$$(oc get secret eda-github-token -n sovereign-cloud-jobs -o jsonpath='{.data.token}' | base64 -d) && \
	export OCI_REGISTRY=$$(oc get secret eda-oci-credentials -n sovereign-cloud-jobs -o jsonpath='{.data.registry}' | base64 -d) && \
	export OCI_ROBOT_USERNAME=$$(oc get secret eda-oci-credentials -n sovereign-cloud-jobs -o jsonpath='{.data.username}' | base64 -d) && \
	export OCI_ROBOT_PASSWORD=$$(oc get secret eda-oci-credentials -n sovereign-cloud-jobs -o jsonpath='{.data.password}' | base64 -d) && \
	export EDA_ADMIN_PASSWORD=$$(oc get secret sovereign-aap-admin-password -n aap -o jsonpath='{.data.password}' | base64 -d) && \
	export EVENT_STREAM_TOKEN=$$(oc get secret event-stream-token -n sovereign-cloud-jobs -o jsonpath='{.data.token}' | base64 -d) && \
	echo "$(BOLD)Running eda-config.yml (live ansible/ mount)...$(RESET)" && \
	podman run --rm \
	  -v "$(CURDIR)/ansible/project/eda-config.yml:/runner/project/eda-config.yml:Z" \
	  -v "$(CURDIR)/ansible/roles:/runner/project/roles:Z" \
	  -e EDA_CONTROLLER_URL -e AAP_CONTROLLER_URL -e AAP_RESOURCE_TOKEN \
	  -e RULEBOOK_REPO_URL -e GITHUB_TOKEN \
	  -e OCI_REGISTRY -e OCI_ROBOT_USERNAME -e OCI_ROBOT_PASSWORD \
	  -e EDA_ADMIN_PASSWORD -e EVENT_STREAM_TOKEN \
	  --entrypoint ansible-playbook \
	  quay.signal9.gg/hybrid-sovereign/ansible-runner:latest \
	  /runner/project/eda-config.yml
	$(call ok,eda-config.yml completed successfully)
