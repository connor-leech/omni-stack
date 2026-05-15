#!/usr/bin/env bash
# bootstrap.sh — bring the stack up, wait for healthchecks, and print the
# one-time API import command + manifest URL pattern Omni connects to.
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

One-time setup (do this once per fresh install, or after wiping volumes):

  1. AIOMetadata — http://${HOST_NAME}:${AIOMETADATA_PORT}
     - Open Settings → Providers; confirm TMDB / TVDB are live.
     - Run the Trakt OAuth flow (Settings → Apps → Trakt). This is interactive
       and can't be scripted.
     - Note the AIOMetadata UUID from its manifest URL — the AIOStreams
       template references it as \${AIOMETADATA_UUID}. Open
       configs/rendered/aiostreams.json and replace that placeholder with the
       real UUID before running step 2.

  2. AIOStreams — load the rendered config via the API. Pick a user password
     (used by /configure to unlock this config) and run:

       PW='choose-a-password'
       python3 -c "
       import json, os
       with open('configs/rendered/aiostreams.json') as f: c = json.load(f)
       c['addonPassword'] = os.environ['AIOSTREAMS_PASSWORD']
       print(json.dumps({'password': os.environ['PW'], 'config': c}))
       " | PW="\$PW" curl -s -X POST http://localhost:${AIOSTREAMS_PORT}/api/v1/user \\
            -H 'Content-Type: application/json' --data-binary @-

     The response contains a \`uuid\`. Fetch the encrypted password token:

       curl -s "http://localhost:${AIOSTREAMS_PORT}/api/v1/user?uuid=<UUID>&password=\$PW"

     The \`encryptedPassword\` field in that response goes in the manifest URL.

  3. Paste this manifest URL into Omni (and save a copy to MANIFEST_URL.txt
     for reference — gitignored):

       http://${HOST_NAME}:${AIOSTREAMS_PORT}/stremio/<UUID>/<encryptedPassword>/manifest.json

Useful URLs:
  AIOStreams   UI : http://${HOST_NAME}:${AIOSTREAMS_PORT}
  AIOMetadata  UI : http://${HOST_NAME}:${AIOMETADATA_PORT}
================================================================================
EOF
