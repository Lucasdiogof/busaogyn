#!/usr/bin/env bash
# Usage (from the app repo): bash scripts/build-web.sh [env.json]
# Builds Flutter Web release with the public Supabase keys from a gitignored JSON file.
# Extra flags via FLUTTER_WEB_FLAGS (e.g. --no-web-resources-cdn to bundle CanvasKit)
set -euo pipefail
ENV_FILE="${1:-env.json}"
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE (copy environment.example.json)"; exit 1; }
flutter pub get
flutter build web --release --dart-define-from-file="$ENV_FILE" ${FLUTTER_WEB_FLAGS:-}
bash "$(dirname "$0")/check-bundle-secrets.sh" build/web
echo "OK: build/web ready"
