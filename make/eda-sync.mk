##@ EDA — Upload and Sync

EDA_JOB_NAMESPACE := sovereign-cloud-jobs
EDA_ARGOCD_APP    := job-eda-config
EDA_DE_REGISTRY   ?= $(OCI_REGISTRY)/hybrid-sovereign
EDA_DE_TAG        ?= latest

.PHONY: upload-eda-de
upload-eda-de: check-env ## Build and push all EDA Decision Environment images to OCI registry
	@echo "$(BOLD)Building and pushing EDA Decision Environment images...$(RESET)"
	@for de_dir in ansible/imagebuild/eda-de/*/; do \
	  de_name=$$(basename "$$de_dir"); \
	  image="$(EDA_DE_REGISTRY)/eda-de-$${de_name}:$(EDA_DE_TAG)"; \
	  echo "  Building $$image..."; \
	  podman build -t "$$image" "$$de_dir" || exit 1; \
	  podman push "$$image" || exit 1; \
	  echo "  ✓  Pushed $$image"; \
	done
	$(call ok,EDA Decision Environment images pushed — re-run: make eda-sync)

.PHONY: eda-sync
eda-sync: check-env-central ## Re-run EDA config job (delete existing Job + hard-refresh ArgoCD app)
	@echo "$(BOLD)Logging in to central cluster...$(RESET)"
	@$(call sovereign_login_central)
	@echo "$(BOLD)Deleting existing EDA config Job (ArgoCD will recreate)...$(RESET)"
	@oc delete job -n $(EDA_JOB_NAMESPACE) \
	  -l app.kubernetes.io/name=$(EDA_ARGOCD_APP) \
	  --ignore-not-found=true 2>/dev/null || true
	@echo "$(BOLD)Hard-refreshing ArgoCD Application $(EDA_ARGOCD_APP)...$(RESET)"
	@oc annotate applications.argoproj.io $(EDA_ARGOCD_APP) \
	  -n openshift-gitops \
	  argocd.argoproj.io/refresh=hard \
	  --overwrite > /dev/null
	$(call ok,EDA sync triggered — watch: oc get jobs -n $(EDA_JOB_NAMESPACE))

.PHONY: eda-status
eda-status: check-env-central ## Show EDA config job status and recent logs
	@$(call sovereign_login_central)
	@oc get jobs -n $(EDA_JOB_NAMESPACE) -l app.kubernetes.io/name=$(EDA_ARGOCD_APP) 2>/dev/null || true
	@echo ""
	@oc logs -n $(EDA_JOB_NAMESPACE) \
	  -l app.kubernetes.io/name=$(EDA_ARGOCD_APP) \
	  --tail=50 2>/dev/null || echo "No logs yet"
