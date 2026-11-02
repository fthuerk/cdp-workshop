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

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

expect() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

beeline_q() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "$1" 2>/dev/null | tail -1 || true
}

db="$(beeline_q 'SHOW DATABASES LIKE '\''ranger_lab'\'';')"
if [[ "${db}" == "ranger_lab" ]]; then pass "database ranger_lab exists"; else fail_msg "database ranger_lab missing"; fi

meter_count="$(beeline_q 'SELECT COUNT(*) FROM ranger_lab.meter_readings;')"
expect "meter_readings row count" "${meter_count}" "30" "run setup.sh"

master_count="$(beeline_q 'SELECT COUNT(*) FROM ranger_lab.customer_master;')"
expect "customer_master row count" "${master_count}" "5" "run setup.sh"

assign_count="$(beeline_q 'SELECT COUNT(*) FROM ranger_lab.station_assignment;')"
if [[ -n "${assign_count}" && "${assign_count}" -ge 2 ]]; then
  pass "station_assignment has ${assign_count} rows"
else
  fail_msg "station_assignment empty or missing (got '${assign_count}')"
fi

echo "[INFO] Not checked here: Ranger policies or participant SELECT access."

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "I2-basics-ranger setup verify complete."
