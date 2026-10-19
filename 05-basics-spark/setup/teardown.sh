#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit

MODULE_ROOT="${WORKSHOP_ROOT}/05-spark"
hdfs dfs -rm -f "${MODULE_ROOT}/assets/spark_cleanse_join.py" 2>/dev/null || true
log_info "Removed shared Spark script under ${MODULE_ROOT}/assets (work/ kept)"
