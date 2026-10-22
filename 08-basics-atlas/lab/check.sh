#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARTICIPANT_HS2_URL="${HS2_URL:-}"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config
HS2_URL="${PARTICIPANT_HS2_URL:-${HS2_URL}}"

require_cmd beeline
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
DB="${WS_USER}"

beeline_q() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "USE ${DB}; $1" 2>/dev/null | tail -1 || true
}

expect() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

expect "atlas_meter_src exists" "$(beeline_q 'SHOW TABLES LIKE '\''atlas_meter_src'\''')" "atlas_meter_src" "lab section 1"
expect "atlas_meter_daily exists" "$(beeline_q 'SHOW TABLES LIKE '\''atlas_meter_daily'\''')" "atlas_meter_daily" "lab section 3"
expect "atlas_meter_anonymized exists" "$(beeline_q 'SHOW TABLES LIKE '\''atlas_meter_anonymized'\''')" "atlas_meter_anonymized" "lab section 3"

row_count="$(beeline_q 'SELECT COUNT(*) FROM atlas_meter_src')"
expect "atlas_meter_src row count" "${row_count}" "8" "lab section 1"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Atlas lab self-check passed (Hive tables only; Atlas UI steps are not verified here)."
