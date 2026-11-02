#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd beeline

: "${HS2_URL:?Set HS2_URL in config.env}"

beeline_q() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "$1" 2>/dev/null || true
}

log_info "Dropping ranger_lab tables and database"
beeline_q "DROP TABLE IF EXISTS ranger_lab.meter_readings;"
beeline_q "DROP TABLE IF EXISTS ranger_lab.customer_master;"
beeline_q "DROP TABLE IF EXISTS ranger_lab.station_assignment;"
beeline_q "DROP DATABASE IF EXISTS ranger_lab;"

log_warn "Remove or disable Ranger policies on ranger_lab in the Ranger UI if you created them for this lab."
log_info "I2-basics-ranger teardown complete."
