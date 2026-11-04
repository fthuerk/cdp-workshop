#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARTICIPANT_IMPALA_OPTS="${IMPALA_OPTS:-}"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config
IMPALA_OPTS="${PARTICIPANT_IMPALA_OPTS}"
require_cmd hdfs impala-shell
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
DB="${WS_USER}"
TYPES_EXT="${TYPES_EXT:-/warehouse/tablespace/external/hive/${DB}.db}"
SHARED="${WORKSHOP_ROOT}/14-datatypes/edge/edge-values.csv"

impala_q() {
  impala-shell ${IMPALA_OPTS} --quiet --delimited -q "INVALIDATE METADATA ${DB}.edge_values; USE ${DB}; $1" 2>/dev/null | tail -1 || true
}

expect() { # description, actual, expected, hint
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

if hdfs dfs -test -e "${SHARED}" 2>/dev/null; then
  pass "shared edge file present"
else
  fail_msg "Missing ${SHARED} - ask your instructor to run the module setup"
fi

if hdfs dfs -test -e "${TYPES_EXT}/edge_values/edge-values.csv" 2>/dev/null; then
  pass "edge-values.csv in ${TYPES_EXT}/edge_values"
else
  fail_msg "Missing ${TYPES_EXT}/edge_values/edge-values.csv - redo lab section 1"
fi

expect "edge_values row count" "$(impala_q 'SELECT COUNT(*) FROM edge_values')" "6" "lab section 1"
expect "raw text kept as text (row 3 raw_int)" "$(impala_q "SELECT raw_int FROM edge_values WHERE row_id = '3'")" "2147483648" "lab section 1 (all columns must be STRING)"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Data types lab self-check passed."
