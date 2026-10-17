#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

log_warn "Removing HDFS path ${WORKSHOP_ROOT} (includes all module data under it)"
read -r -p "Type YES to continue: " confirm
if [[ "${confirm}" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

hdfs dfs -rm -r -skipTrash "${WORKSHOP_ROOT}" 2>/dev/null || true
log_info "Teardown complete for ${WORKSHOP_ROOT}"
