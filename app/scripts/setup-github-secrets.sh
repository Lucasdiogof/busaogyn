#!/usr/bin/env bash
# Usage: bash scripts/setup-github-secrets.sh <owner/repo> <env.json>
# Reads SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY from env.json (public keys only) and CLOUDFLARE_* from the
# environment, then stores them as repo secrets via gh. Never prints values. Refuses privileged keys.
set -euo pipefail
REPO="${1:?owner/repo}"; ENV_FILE="${2:?env.json}"
: "${CLOUDFLARE_API_TOKEN:?export CLOUDFLARE_API_TOKEN (token with Workers Scripts: Edit)}"
: "${CLOUDFLARE_ACCOUNT_ID:?export CLOUDFLARE_ACCOUNT_ID}"
val() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$ENV_FILE" "$1" 2>/dev/null || python -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$ENV_FILE" "$1"; }
KEY="$(val SUPABASE_PUBLISHABLE_KEY)"
case "$KEY" in sb_secret_*) echo "Refusing a secret key"; exit 1;; esac
printf '%s' "$(val SUPABASE_URL)" | gh secret set SUPABASE_URL -R "$REPO"
printf '%s' "$KEY" | gh secret set SUPABASE_PUBLISHABLE_KEY -R "$REPO"
printf '%s' "$CLOUDFLARE_API_TOKEN" | gh secret set CLOUDFLARE_API_TOKEN -R "$REPO"
printf '%s' "$CLOUDFLARE_ACCOUNT_ID" | gh secret set CLOUDFLARE_ACCOUNT_ID -R "$REPO"
echo "Secrets set on $REPO. Enable auto deploy: gh variable set AUTO_DEPLOY -b true -R $REPO"
