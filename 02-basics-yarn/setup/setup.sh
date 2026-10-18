#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/02-yarn"
ASSETS="${MODULE_ROOT}/assets"
INPUT="${MODULE_ROOT}/input"
LOCAL_ASSETS="${WORKSHOP_LOCAL}/02-basics-yarn/assets"

hdfs dfs -mkdir -p "${ASSETS}" "${INPUT}"

for f in spark_linecount.py die-verwandlung-kapitel-1.txt; do
  if [[ ! -f "${LOCAL_ASSETS}/${f}" ]]; then
    log_err "Missing ${LOCAL_ASSETS}/${f} — set WORKSHOP_LOCAL to the repo on the edge node"
    exit 1
  fi
done

hdfs dfs -put -f "${LOCAL_ASSETS}/spark_linecount.py" "${ASSETS}/spark_linecount.py"
hdfs dfs -put -f "${LOCAL_ASSETS}/die-verwandlung-kapitel-1.txt" "${INPUT}/die-verwandlung-kapitel-1.txt"

hdfs dfs -chmod -R 755 "${MODULE_ROOT}" 2>/dev/null || true

log_info "YARN module setup complete under ${MODULE_ROOT}"
