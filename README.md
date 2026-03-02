# GHES ➜ GitHub Migration via GitHub Actions (GEI)

This repository automates **repository migration from GitHub Enterprise Server (GHES) to GitHub (GHEC/GitHub.com)** using **GitHub Actions** and **GitHub Enterprise Importer (GEI)**.

It follows a **staged workflow** pattern similar to bbs2gh-style pipelines:

1. **Pre-migration validation** (readiness checks)
2. **Manual approval gate** (issue-based approval)
3. **Migration execution**
4. **Post-migration validation** (branch + commit + SHA verification)

---

## Repository layout

```text
.github/workflows/
  ghes2gh-staged.yml           # Main staged workflow (pre -> approval -> migrate -> post)
scripts/
  1_migration-readiness.sh     # Stage 1: pre-migration checks [1](https://oneuptime.com/blog/post/2026-01-25-github-actions-environment-protection-rules/view)
  2_migration.sh               # Stage 2: migration runner (parallel) [2](https://www.youtube.com/watch?v=LS2lq1vMFws)
  3_post_migration_validation.sh  # Stage 3: post-migration validation [3](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
  inventory-report.sh          # Generates repos.csv (inventory)
  inventory-report.ps1         # Generates repos.csv (inventory)
repos.csv                       # Input list (can be generated via inventory scripts)
``
