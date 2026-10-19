#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARTICIPANT_IMPALA_OPTS="${IMPALA_OPTS:-}"
PARTICIPANT_HS2_URL="${HS2_URL:-}"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config
IMPALA_OPTS="${PARTICIPANT_IMPALA_OPTS}"
HS2_URL="${PARTICIPANT_HS2_URL:-${HS2_URL}}"

require_cmd hdfs impala-shell
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
DB="ws_${WS_USER}"
IMPALA_WORK="${WORKSHOP_ROOT}/06-impala/work/${WS_USER}"
SCALED="${WORKSHOP_ROOT}/06-impala/scaled/meter-15k.csv"
REPEAT=1000

source_body="$(hdfs dfs -cat "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" 2>/dev/null \
  | awk 'NR > 1 && NF > 0' | wc -l | tr -d ' ')"
expected_rows=$(( source_body * REPEAT ))

impala_q() {
  impala-shell ${IMPALA_OPTS} --quiet --delimited -q "USE ${DB}; $1" 2>/dev/null | tail -1 || true
}

expect() { # description, actual, expected, hint
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail_msg "$1 (got '${2:-nothing}', expected '$3') - $4"; fi
}

if hdfs dfs -test -e "${IMPALA_WORK}/meter/meter-15k.csv" 2>/dev/null; then
  pass "meter CSV in ${IMPALA_WORK}/meter"
else
  fail_msg "Missing ${IMPALA_WORK}/meter/meter-15k.csv - redo lab section 1"
fi

if hdfs dfs -test -e "${SCALED}" 2>/dev/null; then
  pass "shared scaled file present"
else
  fail_msg "Missing ${SCALED} - ask instructor to run 06-basics-impala/setup/setup.sh"
fi

expect "impala_meter row count" "$(impala_q 'SELECT COUNT(*) FROM impala_meter')" "${expected_rows}" "lab sections 1 and 5"
expect "station count" "$(impala_q 'SELECT COUNT(DISTINCT station_id) FROM impala_meter')" "3" "lab section 2"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Impala lab self-check passed."
