#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# GHES -> GHEC Migration: FULL SYNC (Org, Repo, Env, Rules)
# ============================================================

CSV_FILE="${CSV_FILE:-repos.csv}"
GH_PAT="${GH_PAT:?Set GH_PAT (Target GHEC PAT)}"
GH_SOURCE_PAT="${GH_SOURCE_PAT:?Set GH_SOURCE_PAT (Source GHES PAT)}"
GHES_API_URL="${GHES_API_URL:?Set GHES_API_URL}"

API_VERSION="${API_VERSION:-2022-11-28}"
DRY_RUN="${DRY_RUN:-false}"
OVERWRITE="${OVERWRITE:-true}"
TARGET_HOST="${TARGET_HOST:-github.com}"
LOG_DIR="${LOG_DIR:-./var-migration-logs}"
mkdir -p "$LOG_DIR"

GH_HEADERS=(-H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: ${API_VERSION}")

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*"; }
warn() { echo "[$(ts)] [WARN] $*" >&2; }

parse_host_from_url() {
  python3 -c "from urllib.parse import urlparse; import sys; u=sys.argv[1]; print(urlparse(u if '://' in u else 'https://'+u).netloc)" "$1"
}
SOURCE_HOST="$(parse_host_from_url "$GHES_API_URL")"

urlencode() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# -----------------------------
# API Call Wrappers
# -----------------------------
gh_source() {
  local method="$1"; shift; local path="$1"; shift
  GH_TOKEN="$GH_SOURCE_PAT" gh api --hostname "$SOURCE_HOST" -X "$method" "${GH_HEADERS[@]}" "$path" "$@"
}

gh_target() {
  local method="$1"; shift; local path="$1"; shift
  if [[ "$DRY_RUN" == "true" ]]; then return 0; fi
  GH_TOKEN="$GH_PAT" gh api --hostname "$TARGET_HOST" -X "$method" "${GH_HEADERS[@]}" "$path" "$@"
}

# -----------------------------
# Migration Logic
# -----------------------------

migrate_org_vars() {
  local src_org="$1" tgt_org="$2"
  log "Migrating ORG variables: $src_org -> $tgt_org"
  
  gh_source "GET" "/orgs/${src_org}/actions/variables" --jq '.variables[] | "\(.name)\t\(.value)\t\(.visibility)"' 2>/dev/null | while IFS=$'\t' read -r vname vval vvis; do
    local payload; payload=$(python3 -c "import json, sys; print(json.dumps({'name': sys.argv[1], 'value': sys.argv[2], 'visibility': sys.argv[3]}))" "$vname" "$vval" "$vvis")
    
    if gh_target "GET" "/orgs/${tgt_org}/actions/variables/${vname}" >/dev/null 2>&1; then
      [[ "$OVERWRITE" == "true" ]] && gh_target "PATCH" "/orgs/${tgt_org}/actions/variables/${vname}" --input - <<<"$payload" >/dev/null
      log "ORG VAR updated: $tgt_org :: $vname"
    else
      gh_target "POST" "/orgs/${tgt_org}/actions/variables" --input - <<<"$payload" >/dev/null
      log "ORG VAR created: $tgt_org :: $vname"
    fi
  done
}

upsert_repo_var() {
  local tgt_full="$1" name="$2" value="$3"
  local payload; payload=$(python3 -c "import json, sys; print(json.dumps({'name': sys.argv[1], 'value': sys.argv[2]}))" "$name" "$value")

  if gh_target "GET" "/repos/${tgt_full}/actions/variables/${name}" >/dev/null 2>&1; then
    [[ "$OVERWRITE" == "true" ]] && gh_target "PATCH" "/repos/${tgt_full}/actions/variables/${name}" --input - <<<"$payload" >/dev/null && log "REPO VAR updated: $tgt_full :: $name"
  else
    gh_target "POST" "/repos/${tgt_full}/actions/variables" --input - <<<"$payload" >/dev/null && log "REPO VAR created: $tgt_full :: $name"
  fi
}

migrate_envs_and_rules() {
  local src_full="$1" tgt_full="$2"
  log "Migrating ENVIRONMENTS + VARS + RULES: $src_full -> $tgt_full"
  
  local src_id; src_id=$(gh_source "GET" "/repos/${src_full}" --jq '.id')
  local tgt_id; tgt_id=$(gh_target "GET" "/repos/${tgt_full}" --jq '.id')
  local env_names; env_names=$(gh_source "GET" "/repos/${src_full}/environments" --jq '.environments[].name' 2>/dev/null || echo "")

  while read -r env_name; do
    [[ -z "$env_name" ]] && continue
    local env_enc; env_enc=$(urlencode "$env_name")
    
    # Fetch source rules
    local src_env_json; src_env_json=$(gh_source "GET" "/repos/${src_full}/environments/${env_enc}" 2>/dev/null || echo "")
    
    # Parse Rules with Python (wait_timer and prevent_self_review)
    local rule_payload; rule_payload=$(python3 - <<'PY'
import json, sys
try:
    src = json.loads(sys.stdin.read())
    out = {}
    for rule in src.get("protection_rules", []):
        if rule["type"] == "wait_timer": out["wait_timer"] = rule.get("wait_timer")
        if rule["type"] == "required_reviewers": out["prevent_self_review"] = rule.get("prevent_self_review")
    print(json.dumps(out))
except: print("{}")
PY
<<<"$src_env_json")

    # Sync Environment with Rules
    gh_target "PUT" "/repos/${tgt_full}/environments/${env_enc}" --input - <<<"$rule_payload" >/dev/null
    log "ENV rules applied (best-effort): $tgt_full :: $env_name"

    # Sync Env Variables
    gh_source "GET" "/repositories/${src_id}/environments/${env_enc}/variables" --jq '.variables[] | "\(.name)\t\(.value)"' 2>/dev/null | while IFS=$'\t' read -r vname vval; do
      local var_payload; var_payload="{\"name\":\"$vname\",\"value\":\"$vval\"}"
      gh_target "POST" "/repositories/${tgt_id}/environments/${env_enc}/variables" --input - <<<"$var_payload" >/dev/null 2>&1 || \
      gh_target "PATCH" "/repositories/${tgt_id}/environments/${env_enc}/variables/${vname}" --input - <<<"$var_payload" >/dev/null
      log "ENV VAR updated: repo_id=$tgt_id env=$env_name :: $vname"
    done
  done <<< "$env_names"
}

# -----------------------------
# Main Loop
# -----------------------------
main() {
  log "Starting GHES -> GHEC migration"
  
  # Track unique org pairs to avoid redundant org variable calls
  declare -A seen_orgs

  sed 1d "$CSV_FILE" | while IFS=',' read -r g_org g_repo r_url r_size t_org t_repo t_vis; do
    src_org=$(echo "$g_org" | xargs | tr -d '"'); src_repo=$(echo "$g_repo" | xargs | tr -d '"')
    tgt_org=$(echo "$t_org" | xargs | tr -d '"'); tgt_repo=$(echo "$t_repo" | xargs | tr -d '"')
    [[ -z "$src_org" || -z "$src_repo" ]] && continue

    # 1. Org Variables (once per org pair)
    if [[ -z "${seen_orgs["$src_org"]+x}" ]]; then
      migrate_org_vars "$src_org" "$tgt_org"
      seen_orgs["$src_org"]=1
    fi

    # 2. Repo Variables
    src_full="${src_org}/${src_repo}"; tgt_full="${tgt_org}/${tgt_repo}"
    log "Migrating REPO variables: $src_full -> $tgt_full"
    gh_source "GET" "/repos/${src_full}/actions/variables" --jq '.variables[] | "\(.name)\t\(.value)"' 2>/dev/null | while IFS=$'\t' read -r vname vval; do
      upsert_repo_var "$tgt_full" "$vname" "$vval"
    done

    # 3. Environments & Rules
    migrate_envs_and_rules "$src_full" "$tgt_full"
  done
  log "Done."
}

main "$@"
