#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd hdfs awk

MODULE_ROOT="${WORKSHOP_ROOT}/01-hdfs"
LAB="${MODULE_ROOT}/lab"
QUOTA="${MODULE_ROOT}/quota_reached"
SECRET="${MODULE_ROOT}/secret"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${LAB}/dummy.txt"
check hdfs dfs -test -e "${LAB}/bigfile_192mb.bin"
check hdfs dfs -test -e "${SECRET}/secret.txt"

size="$(hdfs dfs -du -s "${LAB}/bigfile_192mb.bin" 2>/dev/null | awk '{print $1}')"
if [[ -n "${size}" && "${size}" -ge 190000000 ]]; then
  echo "[PASS] bigfile size ~192 MB (${size} bytes reported)"
else
  echo "[FAIL] bigfile size unexpected: ${size:-missing}"
  fail=1
fi

quota_out="$(hdfs dfs -count -q "${QUOTA}" 2>/dev/null | head -1 || true)"
if echo "${quota_out}" | grep -q .; then
  echo "[PASS] quota metadata visible for quota_reached"
else
  echo "[WARN] could not read quota for ${QUOTA}"
fi

perm="$(hdfs dfs -ls -d "${SECRET}" 2>/dev/null | awk '{print $1}')"
if [[ "${perm}" == drwx------* ]]; then
  echo "[PASS] secret directory mode restricted (${perm})"
else
  echo "[WARN] secret permissions may be too open: ${perm}"
fi

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "01-basics-hdfs setup verify complete."
