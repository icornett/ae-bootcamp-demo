#!/usr/bin/env bash
set -euo pipefail

IMAGE="${GHCR_IMAGE:-ghcr.io/icornett/training-log}"
REPO_PATH="${IMAGE#ghcr.io/}"
STATE_FILE="${GHCR_LATEST_DIGEST_FILE:-.git/ghcr/latest.digest}"

if ! command -v curl >/dev/null 2>&1; then
  echo "[ghcr-hook] curl not found; skipping digest check."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[ghcr-hook] gh CLI not found; skipping digest check."
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[ghcr-hook] gh auth not configured; skipping digest check."
  exit 0
fi

username="${GHCR_USERNAME:-$(gh api user -q .login 2>/dev/null || true)}"
if [ -z "$username" ]; then
  echo "[ghcr-hook] could not determine GitHub username; skipping digest check."
  exit 0
fi

token_json="$(curl -fsSL -u "$username:$(gh auth token)" "https://ghcr.io/token?scope=repository:${REPO_PATH}:pull")"
token="$(python3 -c "import sys, json; print(json.load(sys.stdin)['token'])" <<<"$token_json")"

digest="$(curl -fsSI -H "Authorization: Bearer $token" "https://ghcr.io/v2/${REPO_PATH}/manifests/latest" | awk -F': ' 'tolower($1)=="docker-content-digest"{gsub("\r", "", $2); print $2}')"

if [ -z "$digest" ]; then
  echo "[ghcr-hook] no digest found for ${IMAGE}:latest"
  exit 0
fi

mkdir -p "$(dirname "$STATE_FILE")"
previous=""
if [ -f "$STATE_FILE" ]; then
  previous="$(cat "$STATE_FILE")"
fi

if [ "$digest" != "$previous" ]; then
  echo "[ghcr-hook] latest digest changed: ${previous:-<none>} -> ${digest}"
else
  echo "[ghcr-hook] latest digest unchanged: ${digest}"
fi

printf '%s\n' "$digest" > "$STATE_FILE"
