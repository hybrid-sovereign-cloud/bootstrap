# AGENTS.md — Hybrid Sovereign Cloud Bootstrap

Aligns Cursor, Claude, and other agents with `.cursor/rules/sovereign-cloud.mdc` and `CLAUDE.md`.

## Scope

- Change only **`bootstrap/`** and **`architecture/`** (not a parent monorepo root).
- **`make validate-helm`** before declaring chart work done.
- **`git add` / `commit` / `push`** allowed whenever it keeps history clear.

## GitOps default

1. **`phase1-gitops`** — OpenShift GitOps (cluster-scoped) + **`GITHUB_URL`** / **`GITHUB_TOKEN`** → Secret **`platform-git-repository`** (`insecure` supports self-signed Git).
2. **`phase2-applicationset`** — ApplicationSet drives Argo **Applications** (prune, selfHeal, sync waves) for operators, instances, config, and **`argocd-init-job`**.

## Makefile policy

- **`make`** is the supported CLI for cluster workflows.
- Helm for chart installs; **`oc`** for waits, health checks, and documented exceptions.

## References

- `bootstrap/README.md`, `architecture/docs/gitops-bootstrap.md`, `architecture/decisions/0008-gitops-first-applicationset-bootstrap.md`
