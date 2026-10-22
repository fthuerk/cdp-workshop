#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/08-atlas"

if hdfs dfs -test -e "${MODULE_ROOT}"; then
  hdfs dfs -rm -r -f "${MODULE_ROOT}"
  log_info "Removed ${MODULE_ROOT}"
else
  log_info "Nothing to remove at ${MODULE_ROOT}"
fi
