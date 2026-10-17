#!/usr/bin/env bash
# Manual deploy (free). Requires `npx wrangler login` or CLOUDFLARE_API_TOKEN. Usage: bash scripts/deploy-web.sh [env.json]
set -euo pipefail
bash "$(dirname "$0")/build-web.sh" "${1:-env.json}"
npx wrangler deploy
echo "Rollback: npx wrangler rollback  (see docs/cloudflare.md)"
