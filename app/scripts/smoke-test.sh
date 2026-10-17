#!/usr/bin/env bash
# Public post-deploy smoke test for a Flutter Web app on Cloudflare Workers (no accounts, no secrets).
# Usage: smoke-test.sh https://app.lucksrei.com [/deep/route ...]
# Env:   RETRIES (default 6) and RETRY_DELAY seconds (default 10) absorb propagation after a deploy.
# Guards against the SPA-fallback false positive: a missing file also answers 200 with index.html,
# so every asset is checked by content type and size, not by status alone.
set -uo pipefail
BASE="${1:?base url, e.g. https://app.lucksrei.com}"; shift || true
BASE="${BASE%/}"
RETRIES="${RETRIES:-6}"; DELAY="${RETRY_DELAY:-10}"
HOST="${BASE#*://}"; HOST="${HOST%%/*}"
fail=0; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok()   { echo "ok   $*"; }
bad()  { echo "FAIL $*"; fail=1; }
fetch() { # path -> sets code, ctype, size and writes $tmp/body
  local out; out="$(curl -sS -m 30 -o "$tmp/body" -D "$tmp/head" -w '%{http_code} %{size_download}' "$BASE$1" 2>/dev/null)" || out="000 0"
  code="${out% *}"; size="${out#* }"
  ctype="$(grep -i '^content-type:' "$tmp/head" 2>/dev/null | tail -1 | tr -d '\r' | cut -d' ' -f2- | tr 'A-Z' 'a-z')"
}
attempt() { # runs all checks once; returns 0 when clean
  fail=0
  fetch /
  [ "$code" = 200 ] && ok "/ -> 200" || bad "/ -> $code"
  case "$ctype" in text/html*) ok "/ is html";; *) bad "/ content-type '$ctype' (want text/html)";; esac
  grep -q 'flutter_bootstrap.js' "$tmp/body" && ok "html loads flutter_bootstrap.js" || bad "html does not reference flutter_bootstrap.js"
  cp "$tmp/head" "$tmp/head_root"

  fetch /flutter_bootstrap.js
  { [ "$code" = 200 ] && case "$ctype" in *javascript*) true;; *) false;; esac; } && ok "flutter_bootstrap.js is javascript" || bad "flutter_bootstrap.js -> $code '$ctype'"
  fetch /main.dart.js
  { [ "$code" = 200 ] && case "$ctype" in *javascript*) true;; *) false;; esac && [ "${size:-0}" -gt 100000 ]; } \
    && ok "main.dart.js is javascript (${size} bytes)" || bad "main.dart.js -> $code '$ctype' ${size} bytes (SPA fallback or empty?)"
  fetch /manifest.json
  { [ "$code" = 200 ] && case "$ctype" in *json*) true;; *) false;; esac; } && ok "manifest.json is json" || bad "manifest.json -> $code '$ctype'"
  fetch /version.json
  { [ "$code" = 200 ] && case "$ctype" in *json*) true;; *) false;; esac; } && ok "version.json is json" || bad "version.json -> $code '$ctype'"

  local routes=("$@"); [ ${#routes[@]} -eq 0 ] && routes=("/rota/profunda")
  for r in "${routes[@]}"; do
    fetch "$r"
    { [ "$code" = 200 ] && case "$ctype" in text/html*) true;; *) false;; esac; } && ok "deep link $r falls back to html" || bad "deep link $r -> $code '$ctype'"
  done

  for k in x-content-type-options strict-transport-security x-frame-options referrer-policy; do
    grep -qi "^$k:" "$tmp/head_root" && ok "header $k" || bad "header $k missing"
  done
  cc="$(grep -i '^cache-control:' "$tmp/head_root" | tr -d '\r' | cut -d' ' -f2-)"; echo "info cache-control: ${cc:-none}"
  case "$HOST" in
    *.workers.dev) echo "info http->https redirect not enforced on workers.dev (HSTS header is checked instead)";;
    *) loc="$(curl -sS -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' "http://$HOST/" 2>/dev/null || echo '000 ')"
       case "$loc" in 301\ https://*|302\ https://*|307\ https://*|308\ https://*) ok "http redirects to https";; *) bad "http://$HOST/ -> $loc (want redirect to https)";; esac;;
  esac
  return $fail
}

n=1
until attempt "$@"; do
  [ "$n" -ge "$RETRIES" ] && { echo "SMOKE FAILED for $BASE after $n attempts"; exit 1; }
  echo "--- attempt $n failed, retrying in ${DELAY}s"; n=$((n+1)); sleep "$DELAY"
done
echo "SMOKE PASSED for $BASE (attempt $n)"
