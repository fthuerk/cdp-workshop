#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/03-hive"
log_info "Removing ${MODULE_ROOT}"
hdfs dfs -rm -r -skipTrash "${MODULE_ROOT}" 2>/dev/null || true
log_info "03-hive teardown complete."
log_warn "Participant databases ws_<user> live in the Hive Metastore; their data is in the Hive warehouse, not in this folder."
log_warn "Drop them as a Hive admin: DROP DATABASE ws_<user> CASCADE; then remove leftover external table folders under /warehouse/tablespace/external/hive/ws_<user>.db (external data is not deleted by DROP)"
