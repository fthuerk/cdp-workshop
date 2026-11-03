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

: "${HS2_URL:?Set HS2_URL in config.env or export HS2_URL}"

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"

beeline_q() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "$1" 2>/dev/null | tail -1 || true
}

expect() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

total="$(beeline_q 'SELECT COUNT(*) FROM cdp_workshop.meter_readings;')"
if [[ -z "${total}" || "${total}" == "0" ]]; then
  fail_msg "SELECT on cdp_workshop.meter_readings failed or returned 0 rows — trainer policies (allow + row filter) may be missing; see lab section 2–4 and troubleshooting.md"
  total=""
fi

if [[ -n "${total}" ]]; then
  assigned="$(beeline_q "SELECT COUNT(*) FROM cdp_workshop.meter_readings m WHERE m.station_id IN (SELECT station_id FROM cdp_workshop.station_assignment WHERE user_name = '${WS_USER}');")"
  expect "visible row count matches station assignment" "${total}" "${assigned}" "lab section 4 (row filter)"
fi

# Masking: customer_name nullify — first non-null count should be 0 when masking policy is active
non_null_names="$(beeline_q "SELECT COUNT(*) FROM cdp_workshop.meter_readings WHERE customer_name IS NOT NULL AND TRIM(customer_name) != '';" 2>/dev/null || echo "err")"
if [[ "${non_null_names}" == "0" ]]; then
  pass "customer_name appears fully masked (nullify)"
elif [[ "${non_null_names}" == "err" || -z "${non_null_names}" ]]; then
  fail_msg "could not evaluate customer_name masking"
else
  fail_msg "customer_name still has clear values (${non_null_names} rows) — trainer masking policy may be missing; see lab section 3"
fi

stations_visible="$(beeline_q 'SELECT COUNT(DISTINCT station_id) FROM cdp_workshop.meter_readings;')"
if [[ -n "${stations_visible}" && "${stations_visible}" -le 2 && "${stations_visible}" -ge 1 ]]; then
  pass "distinct station_id count in range 1–2 (${stations_visible}) with row filter"
else
  fail_msg "expected 1–2 distinct station_id with row filter (got '${stations_visible}')"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Ranger lab self-check passed (Hive outcomes; Ranger UI steps are not verified here)."
