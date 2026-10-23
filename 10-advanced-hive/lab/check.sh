#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# keep the HS2_URL you exported in the lab; config.env would overwrite it
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

# Run SQL in your database; print the last output line (empty if the query failed).
sql() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "USE ${DB}; $1" 2>/dev/null | tail -1 || true
}

expect() { # description, actual, expected, hint
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

expect "landisgyr_v view works" "$(sql 'SELECT COUNT(*) FROM landisgyr_v')" "15" "lab section 0"
expect "stations table has rows" "$(sql 'SELECT COUNT(*) FROM stations')" "3" "lab section 0"
expect "joined readings and weather (no row multiplication)" "$(sql 'WITH w AS (SELECT ts_utc, AVG(temperature_c) AS t FROM weather_operator GROUP BY ts_utc) SELECT COUNT(*) FROM landisgyr_csv m JOIN w ON m.ts_utc = w.ts_utc')" "15" "lab section 1"
expect "one top-load reading per station (window function)" "$(sql 'SELECT COUNT(*) FROM (SELECT ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY transformer_load_pct DESC) AS rn FROM landisgyr_v) r WHERE rn = 1')" "3" "lab section 2"
expect "WKT point for every station" "$(sql "SELECT COUNT(*) FROM stations WHERE CONCAT('POINT(', CAST(longitude AS STRING), ' ', CAST(latitude AS STRING), ')') LIKE 'POINT(%'")" "3" "lab section 4"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed."
  exit 1
fi
echo "Advanced Hive lab self-check passed."
