#!/usr/bin/env bash
# List which screenshots linked in the lab are still missing.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB="${HERE}/../lab_basics_atlas.md"

missing=0
for f in $(grep -o 'img/atlas-[a-z0-9-]*\.png' "${LAB}" | sort -u); do
  if [[ -f "${HERE}/../${f}" ]]; then
    echo "[ok]      ${f}"
  else
    echo "[missing] ${f}"
    missing=$((missing + 1))
  fi
done

echo "${missing} screenshot(s) missing (fallback text is shown in the lab for those)."
