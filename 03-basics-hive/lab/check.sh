#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# keep the HS2_URL you exported in the lab; config.env would overwrite it
PARTICIPANT_HS2_URL="${HS2_URL:-}"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config
HS2_URL="${PARTICIPANT_HS2_URL:-${HS2_URL}}"

require_cmd hdfs beeline
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
DB="ws_${WS_USER}"
# default external warehouse folder of your database (same default as in the lab)
HIVE_EXT="${HIVE_EXT:-/warehouse/tablespace/external/hive/${DB}.db}"

# Run SQL in your database; print the last output line (empty if the query failed).
sql() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "USE ${DB}; $1" 2>/dev/null | tail -1 || true
}

expect() { # description, actual, expected, hint
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

source_rows="$(hdfs dfs -cat "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" 2>/dev/null | wc -l | tr -d ' ')"
source_rows=$(( source_rows - 1 ))

if hdfs dfs -test -e "${HIVE_EXT}/landisgyr_csv/sample-landisgyr-data.csv" 2>/dev/null; then
  pass "CSV copy in ${HIVE_EXT}/landisgyr_csv"
else
  fail_msg "Missing ${HIVE_EXT}/landisgyr_csv/sample-landisgyr-data.csv - redo lab section 1"
fi

expect "landisgyr_csv rows" "$(sql 'SELECT COUNT(*) FROM landisgyr_csv')" "${source_rows}" "lab sections 1-2"
expect "landisgyr_by_station rows (all partitions)" "$(sql 'SELECT COUNT(*) FROM landisgyr_by_station')" "${source_rows}" "lab section 3 (ADD PARTITION / MSCK REPAIR)"
expect "meter_orc rows" "$(sql 'SELECT COUNT(*) FROM meter_orc')" "15000" "lab sections 4-5 (INSERT OVERWRITE)"
expect "meter_parquet rows" "$(sql 'SELECT COUNT(*) FROM meter_parquet')" "15000" "lab section 4"
expect "meter_part merged row for TS-101" "$(sql "SELECT COUNT(*) FROM meter_part WHERE ts_utc = '2026-01-15T09:15:00Z'")" "1" "lab section 6 (merge by rewrite)"
expect "landisgyr_managed is transactional" "$(sql 'SHOW TBLPROPERTIES landisgyr_managed("transactional")')" "true" "lab section 7"
expect "landisgyr_managed MERGE inserted the new reading" "$(sql "SELECT COUNT(*) FROM landisgyr_managed WHERE ts_utc = '2026-01-15T09:15:00Z'")" "1" "lab section 8"
expect "landisgyr_v view works" "$(sql 'SELECT COUNT(*) FROM landisgyr_v')" "${source_rows}" "lab section 9"
expect "joined readings and weather (no row multiplication)" "$(sql 'WITH w AS (SELECT ts_utc, AVG(temperature_c) AS t FROM weather_operator GROUP BY ts_utc) SELECT COUNT(*) FROM landisgyr_csv m JOIN w ON m.ts_utc = w.ts_utc')" "${source_rows}" "lab section 10"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Hive lab self-check passed."
