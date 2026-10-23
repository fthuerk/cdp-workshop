#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

# This module has no shared folders: participants create their database and external tables in the
# default external warehouse folder of <user> and copy the sample files there (lab section 0,
# safe to repeat). Nothing to create here; the script only checks what the lab copies from.
if ! hdfs dfs -test -d /warehouse/tablespace/external/hive; then
  log_err "Missing /warehouse/tablespace/external/hive - check the Hive warehouse location"
  exit 1
fi
for f in landisgyr/sample-landisgyr-data.csv basemap/sample-basemap-at-locations.csv \
         awattar/sample-awattar-prices.csv operator_weather/sample-operator-weather.csv; do
  if ! hdfs dfs -test -e "${WORKSHOP_ROOT}/data/${f}"; then
    log_err "Missing ${WORKSHOP_ROOT}/data/${f} - run 00-setup/admin/bootstrap.sh first"
    exit 1
  fi
done

log_info "Advanced Hive module has no folders to prepare."
log_warn "Ranger: same policies as module 04 (Hive on {USER}, HDFS rwx on /warehouse/tablespace/external/hive/{USER}.db, read on ${WORKSHOP_ROOT}/data) - see 00-setup/admin/ranger/README.md"
