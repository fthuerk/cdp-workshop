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

# Section 1: idempotent loads by hand (external tables)
expect "meter_part has six TS-101 readings (merge by rewrite)" \
  "$(sql "SELECT COUNT(*) FROM meter_part WHERE station_id = 'TS-101'")" "6" "lab section 1"

# Section 2: the Iceberg table and its files
expect "ice_meter is an Iceberg table" \
  "$(sql 'SHOW TBLPROPERTIES ice_meter("table_type")')" "ICEBERG" "lab section 2"
expect "ice_meter uses format version 2" \
  "$(sql 'SHOW TBLPROPERTIES ice_meter("format-version")')" "2" "lab section 2 (TBLPROPERTIES)"
if hdfs dfs -test -d "${HIVE_EXT}/ice_meter/metadata" 2>/dev/null \
   && hdfs dfs -test -d "${HIVE_EXT}/ice_meter/data" 2>/dev/null; then
  pass "metadata/ and data/ folders in ${HIVE_EXT}/ice_meter"
else
  fail_msg "Missing metadata/ or data/ under ${HIVE_EXT}/ice_meter - redo lab section 2"
fi

# Sections 3-5: Hive, Impala, and Spark changes (still true after the rollback in section 9)
expect "ice_meter rows after all changes" "$(sql 'SELECT COUNT(*) FROM ice_meter')" "13" "lab sections 3-5 (and rollback in 9)"
expect "TS-101 has six readings (Hive MERGE)" \
  "$(sql "SELECT COUNT(*) FROM ice_meter WHERE station_id = 'TS-101'")" "6" "lab section 3"
expect "TS-305 HIGH_LOAD rows deleted (Hive DELETE)" \
  "$(sql "SELECT COUNT(*) FROM ice_meter WHERE station_id = 'TS-305' AND event_code = 'HIGH_LOAD'")" "0" "lab section 3"
expect "TS-204 maintenance flag set (Impala UPDATE)" \
  "$(sql "SELECT COUNT(*) FROM ice_meter WHERE station_id = 'TS-204' AND comm_status <> 'MAINTENANCE'")" "0" "lab section 4"
expect "TS-204 early readings deleted (Impala DELETE)" \
  "$(sql "SELECT COUNT(*) FROM ice_meter WHERE station_id = 'TS-204' AND ts_utc < '2026-01-15T08:30:00Z'")" "0" "lab section 4"
expect "TS-204 09:15 reading inserted (Spark MERGE)" \
  "$(sql "SELECT COUNT(*) FROM ice_meter WHERE station_id = 'TS-204' AND ts_utc = '2026-01-15T09:15:00Z'")" "1" "lab section 5"

# Sections 6-9: history exists (snapshots from several engines, or one after the expire step)
snapshots="$(sql "SELECT COUNT(*) FROM ${DB}.ice_meter.snapshots")"
if [[ "${snapshots}" =~ ^[0-9]+$ && "${snapshots}" -ge 1 ]]; then
  pass "ice_meter has ${snapshots} snapshot(s)"
else
  fail_msg "Could not read ${DB}.ice_meter.snapshots (got '${snapshots:-nothing}') - lab section 6"
fi

# Section 8: range join returns one row per reading
expect "range join readings x prices (no row multiplication)" \
  "$(sql "SELECT COUNT(*) FROM ice_meter m JOIN market_prices p ON SUBSTR(m.ts_utc,1,10) = SUBSTR(p.timestamp_start,1,10) AND m.ts_utc >= p.timestamp_start AND m.ts_utc < p.timestamp_end")" \
  "13" "lab section 8 (range join)"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Lakehouse lab self-check passed."
