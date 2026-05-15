#!/usr/bin/env bash
# render-configs.sh — substitute ${VAR} placeholders from .env into
# configs/*.template.json, producing configs/*.rendered.json (gitignored).
#
# Usage: ./scripts/render-configs.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "error: .env not found. Copy .env.example to .env and fill in keys." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

required=(TMDB_API_KEY TVDB_API_KEY TORBOX_API_KEY AIOSTREAMS_PASSWORD AIOSTREAMS_SECRET_KEY)
missing=()
for v in "${required[@]}"; do
  if [[ -z "${!v:-}" ]]; then missing+=("$v"); fi
done
if (( ${#missing[@]} > 0 )); then
  echo "error: missing required vars in .env: ${missing[*]}" >&2
  exit 1
fi

# Optional vars (substituted as empty if unset)
: "${MDBLIST_API_KEY:=}"
: "${RPDB_API_KEY:=}"
: "${REAL_DEBRID_API_KEY:=}"

shopt -s nullglob
for tpl in configs/*.template.json; do
  out="${tpl%.template.json}.rendered.json"
  # envsubst only replaces $VAR / ${VAR} that we explicitly list, so unrelated
  # ${...} in template strings (e.g. ${CLAUDE_PLUGIN_ROOT}) won't get clobbered.
  envsubst '${TMDB_API_KEY} ${TVDB_API_KEY} ${MDBLIST_API_KEY} ${RPDB_API_KEY} ${TORBOX_API_KEY} ${REAL_DEBRID_API_KEY}' \
    < "$tpl" > "$out"
  # Validate the JSON before declaring success.
  python3 -m json.tool "$out" >/dev/null
  echo "rendered $out"
done

echo
echo "Done. The rendered files live alongside the templates and are gitignored."
echo "Import them via the /configure UI of each addon (see README)."
