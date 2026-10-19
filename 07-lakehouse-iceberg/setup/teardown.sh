#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

log_info "07-lakehouse-iceberg has no shared HDFS folders to remove."
log_warn "Participant tables live in ws_<user> databases: DROP DATABASE ws_<user> CASCADE as a Hive admin."
log_warn "Iceberg table folders under /warehouse/tablespace/external/hive/ws_<user>.db/ice_* and meter_part may remain (external tables, depending on external.table.purge): delete them by hand."
