#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

# This module has no shared folders: participants create their database, source tables, and Iceberg
# tables in the default external warehouse folder of their ws_<user> database. Nothing to create here.
if ! hdfs dfs -test -d /warehouse/tablespace/external/hive; then
  log_err "Missing /warehouse/tablespace/external/hive - check the Hive warehouse location"
  exit 1
fi
if ! hdfs dfs -test -e "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"; then
  log_err "Missing workshop data under ${WORKSHOP_ROOT}/data - run 00-setup/admin/bootstrap.sh first"
  exit 1
fi

log_info "Lakehouse module has no folders to prepare."
log_warn "Ranger: besides Hive policies on ws_* and HDFS rwx on the external warehouse folders of ws_*, workshop users need the Iceberg storage handler policy (storage-type iceberg, storage-url *, RW Storage) - see 00-setup/admin/ranger/README.md (module 07)"
log_warn "Runtime: Impala UPDATE/MERGE need 7.3.1.500 or later; Spark needs the Iceberg SQL extensions on the command line (see lab section 5)"
