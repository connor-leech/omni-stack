#!/usr/bin/env bash
# bootstrap.sh — bring the stack up, wait for healthchecks, and print the
# one-time UI steps + the AIOStreams manifest URL pattern Omni connects to.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "error: .env not found. Copy .env.example to .env first, fill in keys, then re-run." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

HOST_NAME="${HOST_NAME:-mini}"
AIOSTREAMS_PORT="${AIOSTREAMS_PORT:-3001}"
AIOMETADATA_PORT="${AIOMETADATA_PORT:-3232}"

echo "==> Rendering config templates from .env"
./scripts/render-configs.sh

echo "==> docker compose up -d"
docker compose up -d

wait_healthy() {
  local svc="$1" tries=60
  echo "   waiting for $svc to become healthy..."
  for ((i=1; i<=tries; i++)); do
    status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$svc" 2>/dev/null || echo "missing")
    case "$status" in
      healthy|running) echo "   $svc: $status"; return 0 ;;
      starting|created) sleep 2 ;;
      *) sleep 2 ;;
    esac
  done
  echo "   warning: $svc never reported healthy. Last status: $status" >&2
  return 1
}

wait_healthy aiometadata_redis || true
wait_healthy aiometadata || true
wait_healthy aiostreams || true

cat <<EOF

================================================================================
omni-stack is up.

One-time UI setup (do this once per fresh install, or after wiping volumes):

  1. AIOMetadata — http://${HOST_NAME}:${AIOMETADATA_PORT}/configure
     - Import configs/aiometadata.rendered.json (Import / Restore button).
     - Save. Copy the manifest URL it gives you (something like
       http://${HOST_NAME}:${AIOMETADATA_PORT}/<UUID>/manifest.json).
     - From inside Docker, AIOStreams will reach AIOMetadata at
       http://aiometadata:3232/<UUID>/manifest.json — use that internal form
       when AIOStreams asks for the custom addon URL.

  2. AIOStreams — http://${HOST_NAME}:${AIOSTREAMS_PORT}/configure
     - Set the addon password to the AIOSTREAMS_PASSWORD value from .env.
     - Import configs/aiostreams.rendered.json (Import / Restore button).
     - Update the AIOMetadata custom-addon entry's manifestUrl to include the
       UUID you got in step 1 (http://aiometadata:3232/<UUID>/manifest.json).
     - Save. Copy the manifest URL it gives you.
     - Trakt: under Catalogs / Apps, run the Trakt OAuth flow (manual).

  3. Paste that AIOStreams manifest URL into Omni.

AIOStreams manifest URL pattern (after you save in /configure):
    http://${HOST_NAME}:${AIOSTREAMS_PORT}/<UUID>/manifest.json

Useful URLs:
  AIOStreams   /configure : http://${HOST_NAME}:${AIOSTREAMS_PORT}/configure
  AIOMetadata  /configure : http://${HOST_NAME}:${AIOMETADATA_PORT}/configure
================================================================================
EOF
