#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit

MODULE_ROOT="${WORKSHOP_ROOT}/05-impala"
hdfs dfs -rm -r -skipTrash "${MODULE_ROOT}/scaled" 2>/dev/null || true
# Leave work/ in place — participant copies and tables may still reference it.
log_info "Removed shared scaled data under ${MODULE_ROOT}/scaled (work/ kept)"
