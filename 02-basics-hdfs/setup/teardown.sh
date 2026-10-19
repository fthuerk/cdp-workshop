#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/02-hdfs"
log_info "Removing ${MODULE_ROOT}"
hdfs dfs -rm -r -skipTrash "${MODULE_ROOT}" 2>/dev/null || true
log_info "02-hdfs teardown complete."
