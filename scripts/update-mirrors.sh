#!/usr/bin/env bash
# update-mirrors.sh — refresh the local copies of upstream regex / SEL / metadata
# configs we depend on. Bumps configs/vidhin-regex.json, configs/tamtaro-sel.json,
# configs/tamtaro-aiometadata.json from their source repos.
set -euo pipefail

cd "$(dirname "$0")/.."
cd configs

declare -A sources=(
  [vidhin-regex.json]="https://raw.githubusercontent.com/Vidhin05/Releases-Regex/main/all-templates.json"
  [tamtaro-sel.json]="https://raw.githubusercontent.com/Tam-Taro/SEL-Filtering-and-Sorting/refs/heads/main/Tamtaro-All-Templates-for-AIOStreams.json"
  [tamtaro-aiometadata.json]="https://raw.githubusercontent.com/Tam-Taro/SEL-Filtering-and-Sorting/refs/heads/main/AIOMetadata%20Configs/Tamtaro-aiometadata-config-without-anime.json"
)

for f in "${!sources[@]}"; do
  url="${sources[$f]}"
  tmp="$(mktemp)"
  if curl -sfL "$url" -o "$tmp"; then
    # Validate JSON before clobbering the existing mirror.
    if python3 -m json.tool "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$f"
      echo "updated $f ($(wc -c < "$f") bytes)"
    else
      rm -f "$tmp"
      echo "warning: $url returned invalid JSON, keeping existing $f" >&2
    fi
  else
    rm -f "$tmp"
    echo "warning: failed to fetch $url, keeping existing $f" >&2
  fi
done

echo
echo "Done. After mirroring, rerun ./scripts/render-configs.sh and re-import"
echo "the rendered files in the /configure UI if you want the new content live."
