# GHES ➜ GitHub.com Migration with GitHub Actions (GEI) — Staged Workflow

This repository provides a **GitHub Actions workflow** to migrate repositories from **GitHub Enterprise Server (GHES)** to **GitHub Enterprise Cloud / GitHub.com** using the **GitHub Enterprise Importer (GEI)** `gh gei` CLI extension. [2](https://www.youtube.com/watch?v=LS2lq1vMFws)

It is modeled after a *bbs2gh-actions* style workflow and now includes a **staged pipeline** with an approval gate: [4](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/migrating-repositories-from-github-enterprise-server-to-github-enterprise-cloud)  
- ✅ **Stage 1: Pre-migration validation** — readiness checks (open PRs, queued/running workflows, open issues) [1](https://oneuptime.com/blog/post/2026-01-25-github-actions-environment-protection-rules/view)  
- 🛂 **Stage 2: Manual approval gate** — pauses and waits for approver before migration (issue-based approval like bbs2gh) [4](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/migrating-repositories-from-github-enterprise-server-to-github-enterprise-cloud)  
- 🚀 **Stage 3: Migration** — parallel repository migrations (max **5** at a time) [2](https://www.youtube.com/watch?v=LS2lq1vMFws)  
- 🔎 **Stage 4: Post-migration validation** — branches + commit counts + latest SHA checks with repo-wise ✅/❌ summary [3](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)  

> **Important**: If your GHES instance is only reachable from your corporate network, run this workflow on a **self-hosted runner** with network access to GHES. [4](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/migrating-repositories-from-github-enterprise-server-to-github-enterprise-cloud)

---

## Repo layout

```text
.github/workflows/
  ghes2gh-staged.yml                 # Main staged workflow (pre → approval → migrate → post)

repos.csv                             # Input list (can be generated via inventory scripts)

scripts/
  1_migration-readiness.sh            # Stage 1: pre-migration checks [1](https://oneuptime.com/blog/post/2026-01-25-github-actions-environment-protection-rules/view)
  2_migration.sh                      # Stage 3: migration runner (parallel) [2](https://www.youtube.com/watch?v=LS2lq1vMFws)
  3_post_migration_validation.sh      # Stage 4: post-migration validation [3](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

  inventory-report.sh                 # Generates repos.csv (inventory)
  inventory-report.ps1                # Generates repos.csv (inventory)
