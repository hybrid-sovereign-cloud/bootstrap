.DEFAULT_GOAL := help

# ─── Required environment variables ──────────────────────────────────────────
REQUIRED_VARS := \
  OCP_CENTRAL_SERVER OCP_CENTRAL_USERNAME OCP_CENTRAL_PASSWORD \
  OCP_SERVICES_SERVER OCP_SERVICES_USERNAME OCP_SERVICES_PASSWORD \
  OCI_REGISTRY OCI_REGISTRY_TOKEN \
  OCI_ROBOT_USERNAME OCI_ROBOT_PASSWORD \
  GITHUB_URL GITHUB_TOKEN \
  IMAGE_REGISTRY IMAGE_REGISTRY_USERNAME IMAGE_REGISTRY_PASSWORD

# ─── Derived OCI values ──────────────────────────────────────────────────────
OCI_HOST := $(shell echo "$(OCI_REGISTRY)" | sed -E 's|^https?://||' | cut -d'/' -f1)
OCI_NAMESPACE := $(shell echo "$(OCI_REGISTRY)" | sed -E 's|^https?://||' | sed -n 's|.*/organization/||p' | cut -d'/' -f1)
ifeq ($(OCI_NAMESPACE),)
  OCI_NAMESPACE := sovereign
endif

# ─── Helpers ──────────────────────────────────────────────────────────────────
BOLD  := $(shell tput bold 2>/dev/null || echo "")
GREEN := $(shell tput setaf 2 2>/dev/null || echo "")
RED   := $(shell tput setaf 1 2>/dev/null || echo "")
RESET := $(shell tput sgr0 2>/dev/null || echo "")

define ok
  @printf "  $(GREEN)✓$(RESET)  %s\n" "$(1)"
endef
define fail
  @printf "  $(RED)✗$(RESET)  %s\n" "$(1)"
endef

# ─── Import targets from make/ ───────────────────────────────────────────────
include make/check-env.mk
include make/add-docker-repo.mk
include make/upload-acm-chart.mk
include make/upload-rhbk-chart.mk
include make/upload-rhbk-config-chart.mk
include make/upload-sovereign-namespaces-chart.mk
include make/ansible-runner.mk
include make/init-central-argo.mk
include make/help.mk
