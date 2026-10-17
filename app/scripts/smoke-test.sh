#!/usr/bin/env bash
# Usage: smoke-test.sh https://app.lucksrei.com [/deep/route ...]
set -uo pipefail
BASE="${1:?base url}"; shift || true
fail=0
check() { # path expected_status
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$1"); [ "$code" = "$2" ] && echo "ok   $1 -> $code" || { echo "FAIL $1 -> $code (want $2)"; fail=1; }; }
check / 200; check /manifest.json 200; check /flutter_bootstrap.js 200; check /main.dart.js 200
for r in "$@"; do check "$r" 200; done   # SPA deep links must not 404
h=$(curl -sI "$BASE/"); for k in x-content-type-options strict-transport-security x-frame-options; do echo "$h" | grep -qi "^$k" && echo "ok   header $k" || { echo "FAIL header $k"; fail=1; }; done
echo "$h" | grep -i '^cache-control'
exit $fail
