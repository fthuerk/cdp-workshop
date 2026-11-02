#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit

hdfs dfs -rm -r -f -skipTrash "${WORKSHOP_ROOT}/08-oozie"
log_info "Removed ${WORKSHOP_ROOT}/08-oozie (participant folders /user/<name>/oozie and Oozie jobs are kept)"
