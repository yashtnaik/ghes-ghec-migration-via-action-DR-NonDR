# GHES ➜ GitHub.com Migration with GitHub Actions (GEI) — Staged Workflow

This repository provides a **GitHub Actions workflow** to migrate repositories from **GitHub Enterprise Server (GHES)** to **GitHub Enterprise Cloud / GitHub.com** using the **GitHub Enterprise Importer (GEI)** `gh gei` CLI extension.

It is modeled after a *bbs2gh-actions* style workflow and implements a **staged migration pipeline** with an explicit approval gate:

- ✅ **Stage 1 – Pre‑migration validation** (open PRs, queued/running workflows, open issues)
- 🛂 **Stage 2 – Manual approval gate** (issue‑based approval before migration)
- 🚀 **Stage 3 – Migration execution** (parallel migrations, max 5 at a time)
- 🔎 **Stage 4 – Post‑migration validation** (branch count, commit count, latest SHA verification)

> **Important**: If your GHES instance is reachable only from your corporate network, run this workflow on a **self‑hosted runner** with network access to GHES.

---

## Repository layout

```
.github/workflows/
  ghes2gh-staged.yml              # Main staged workflow (pre → approval → migrate → post)

repos.csv                          # Migration input list (can be generated via inventory scripts)

scripts/
  1_migration-readiness.sh         # Stage 1: pre-migration checks
  2_migration.sh                   # Stage 3: migration runner (parallel)
  3_post_migration_validation.sh   # Stage 4: post-migration validation

  inventory-report.sh              # Generates repos.csv (inventory)
  inventory-report.ps1             # Generates repos.csv (inventory)
```

---

## Required secrets

Create these repository secrets in **Settings → Secrets and variables → Actions**:

| Secret | Used for |
|---|---|
| `GH_TOKEN` | Auth for `gh` CLI in the workflow (recommended: same value as `GH_PAT`) |
| `GH_PAT` | Target GitHub token (destination org; needs migrator/owner access) |
| `GH_SOURCE_PAT` | Source GHES token |
| `GHES_API_URL` | GHES REST API base URL, e.g. `https://ghe.example.com/api/v3` |

---

## repos.csv format

The scripts expect the following header names (order can vary; extra columns are allowed):

```csv
ghes_org,ghes_repo,repo_url,repo_size_MB,github_org,github_repo,gh_repo_visibility
```

Required columns for migration:
- `ghes_org`, `ghes_repo` (source)
- `github_org`, `github_repo`, `gh_repo_visibility` (target)

---

## Inventory (generate repos.csv)

This repository includes:
- `inventory-report.sh`
- `inventory-report.ps1`

Use these scripts to generate a `repos.csv` inventory file, then commit it before running the migration workflow.

---

## Running the workflow

1. Generate or update `repos.csv` and commit it to the repository.
2. Go to **Actions → ghes-to-github-migration (staged) → Run workflow**.
3. Provide workflow inputs:
   - `csv_path`: path to your CSV (default: `repos.csv`)
   - `max_concurrent`: keep `≤ 5`
   - `approver`: GitHub username(s) who must approve the migration gate
4. Select stage toggles as required:
   - `run_pre_validation`
   - `require_approval`
   - `run_migration`
   - `run_post_validation`

### Manual approval gate

If `require_approval=true`, the workflow creates an approval issue and **waits** until the approver approves before starting migration.

---

## Workflow summaries

Each stage publishes a **Job Summary** in the Actions run UI:

### Pre‑migration summary
- Consolidated counts (repos processed, repos with PRs, workflows, issues)
- **Repo‑wise table** with ✅ / ⚠️ indicators

### Migration summary
- Overall success/failure counts
- **Repo‑wise results table**
- **Clickable GitHub links** for successfully migrated repositories

### Post‑migration validation summary
- **Repo‑wise table** showing ✅ / ❌ for:
  - Branch count match
  - Commit count match
  - SHA match
- Collapsible section with per‑branch mismatch details

---

## Artifacts

Each run uploads artifacts for traceability:

- `precheck.log`
- `repo_migration_output.csv`
- `migration-*.txt`
- `post_validation.log`
- `validation-log-*.txt`, `validation-*.json`

---

## Troubleshooting

- **Approval gate does not pause**: ensure `require_approval=true` and a valid `approver` is provided.
- **Cannot reach GHES**: use a self‑hosted runner with network access.
- **401 / 403 errors**: verify PAT scopes and SSO authorization.
- **CSV not found**: workflow copies `csv_path` to `scripts/repos.csv` for pre/post scripts.
- **Post‑validation mismatches**: review repo‑wise summary and validation logs.

---

## License

Add a license if you plan to publish or distribute this repository.
