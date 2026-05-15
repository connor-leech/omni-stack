#!/usr/bin/env bash
# export-configs.sh — pull current configs back out of running instances so you
# can commit a known-good snapshot into git.
#
# Both AIOStreams and AIOMetadata expose an Export button in /configure that
# downloads the live config as JSON. There is no stable headless export API
# documented for either project, so this script automates as much as it can
# and walks you through the manual download for the rest.
#
# Outputs (overwrite each run):
#   configs/aiostreams.exported.json
#   configs/aiometadata.exported.json
#
# Treat these as the source of truth after you've tuned settings in the UI.
# Re-promote one to the template by:
#   cp configs/aiometadata.exported.json configs/aiometadata.template.json
#   # ...then run scripts/strip-secrets.sh (or hand-edit) before committing.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "error: .env not found." >&2
  exit 1
fi
# shellcheck disable=SC1091
set -a; source .env; set +a

HOST_NAME="${HOST_NAME:-mini}"
AIOSTREAMS_PORT="${AIOSTREAMS_PORT:-3001}"
AIOMETADATA_PORT="${AIOMETADATA_PORT:-3232}"

cat <<EOF
Open each /configure page in a browser, load your saved config (use your UUID
or password), click the Export button, and save the JSON to the paths below:

  configs/aiostreams.exported.json   <- from http://${HOST_NAME}:${AIOSTREAMS_PORT}/configure
  configs/aiometadata.exported.json  <- from http://${HOST_NAME}:${AIOMETADATA_PORT}/configure

These files are GITIGNORED by default (they contain raw API keys). If you want
to update the committed templates, strip secrets first — replace your real
keys with the corresponding \${VAR} placeholders.
EOF

# If you eventually find a stable headless API, drop the curl/jq invocations
# here. As of this writing the export endpoints require an active browser
# session and the in-UI password to render keys.
