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
LOCAL_SCRIPT="${WORKSHOP_LOCAL}/02-basics-yarn/assets/spark_linecount.py"

hdfs dfs -mkdir -p "${ASSETS}"

if [[ ! -f "${LOCAL_SCRIPT}" ]]; then
  log_err "Missing ${LOCAL_SCRIPT} — set WORKSHOP_LOCAL to the repo on the edge node"
  exit 1
fi

hdfs dfs -put -f "${LOCAL_SCRIPT}" "${ASSETS}/spark_linecount.py"

hdfs dfs -chmod -R 755 "${MODULE_ROOT}" 2>/dev/null || true

log_info "YARN module setup complete under ${MODULE_ROOT}"
