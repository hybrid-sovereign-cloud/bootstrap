##@ Build Artifacts

ANSIBLE_RUNNER_IMAGE := $(OCI_HOST)/$(OCI_NAMESPACE)/ansible-runner
ANSIBLE_RUNNER_TAG := latest

.PHONY: ansible-runner
ansible-runner: check-env ## Build ansible-runner image and push to Quay
	@echo "$(BOLD)Creating Quay repository for ansible-runner...$(RESET)"
	@curl -sf -X POST \
	  -H "Authorization: Bearer $(OCI_REGISTRY_TOKEN)" \
	  -H "Content-Type: application/json" \
	  -d '{"repository":"ansible-runner","visibility":"private","description":"Ansible execution environment for sovereign cloud jobs","namespace":"$(OCI_NAMESPACE)"}' \
	  "https://$(OCI_HOST)/api/v1/repository" > /dev/null 2>&1 \
	  && printf "  $(GREEN)✓$(RESET)  Repository created (or exists)\n" \
	  || printf "  $(GREEN)✓$(RESET)  Repository already exists\n"
	@echo "$(BOLD)Logging in to image registry...$(RESET)"
	@echo "$(IMAGE_REGISTRY_PASSWORD)" | podman login "$(IMAGE_REGISTRY)" \
	  --username="$(IMAGE_REGISTRY_USERNAME)" --password-stdin > /dev/null 2>&1
	$(call ok,Logged in to $(IMAGE_REGISTRY))
	@echo "$(BOLD)Building ansible-runner image...$(RESET)"
	@podman build -t "$(ANSIBLE_RUNNER_IMAGE):$(ANSIBLE_RUNNER_TAG)" \
	  -f ansible/imagebuild/ansiblerunner/Containerfile ansible/
	$(call ok,Image built: $(ANSIBLE_RUNNER_IMAGE):$(ANSIBLE_RUNNER_TAG))
	@echo "$(BOLD)Pushing ansible-runner image to Quay...$(RESET)"
	@echo "$(OCI_REGISTRY_TOKEN)" | podman login "$(OCI_HOST)" \
	  --username='$$oauthtoken' --password-stdin > /dev/null 2>&1
	@podman push "$(ANSIBLE_RUNNER_IMAGE):$(ANSIBLE_RUNNER_TAG)"
	$(call ok,Image pushed to $(ANSIBLE_RUNNER_IMAGE):$(ANSIBLE_RUNNER_TAG))
