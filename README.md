# GHES ➜ GitHub.com Migration with GitHub Actions (GEI)

This repository provides a **GitHub Actions workflow** to migrate repositories from **GitHub Enterprise Server (GHES)** to **GitHub Enterprise Cloud / GitHub.com** using the **GitHub Enterprise Importer (GEI)** `gh gei` CLI extension.

It is modeled after an existing *bbs2gh-actions* style workflow: 
- ✅ Pre-migration readiness checks (open PRs, queued/running workflows, open issues)
- ✅ Parallel repository migrations (max 5 at a time)
- ✅ Post-migration validation (branches + commit counts + latest SHA)

> **Important**: If your GHES instance is only reachable from your corporate network, run this workflow on a **self-hosted runner** with network access to GHES.

---

## Repo layout

```
.github/workflows/ghes2gh.yml   # Main workflow
repos.csv                       # Input list
scripts/
  1_migration-readiness.sh
  2_migration.sh
  3_post_migration_validation.sh
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

## `repos.csv` format

The scripts expect the following header names (order can vary, extra columns allowed):

```csv
ghes_org,ghes_repo,repo_url,repo_size_MB,github_org,github_repo,gh_repo_visibility
```

Only these are required by the migration runner:
- `ghes_org`, `ghes_repo` (source)
- `github_org`, `github_repo`, `gh_repo_visibility` (target)

See the sample file at [`repos.csv`](./repos.csv).

---

## Running the workflow

1. Commit your filled `repos.csv`.
2. Go to **Actions → GHES to GitHub Migration (GEI) → Run workflow**.
3. Choose inputs:
   - **max_concurrent**: keep `<= 5`.
   - **use_github_storage**: `true` to pass `--use-github-storage` to GEI.
   - **target_api_url**: optional, for GHE.com data-residency (example: `https://api.SUBDOMAIN.ghe.com`).

Artifacts uploaded after the run:
- `repo_migration_output.csv` (status per repo)
- `migration-*.txt` (per-repo migration logs)
- `validation-log-YYYYMMDD.txt` (validation summary)
- `validation-*.json` (target repo info snapshots)

---

## Notes / prerequisites

- GitHub recommends using the **GitHub CLI** for most GEI migrations, while the API is for advanced automation.  
- You need sufficient permissions to run migrations (owner or **migrator role**) and PATs with the correct scopes in both source and destination.  

---

## Troubleshooting

- **401/403 errors**: make sure your PATs have correct scopes and are authorized for SSO if your org uses SAML.
- **Cannot reach GHES**: use a **self-hosted runner** inside the network.
- **Rate limits**: GitHub Cloud enforces rate limits that may not exist on GHES.

---

## License

Add a license if you plan to publish this repository.
