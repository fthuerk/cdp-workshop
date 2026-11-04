#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
env_livy_url="${LIVY_URL:-}"   # the URL exported for the lab wins over config.env
load_config
LIVY_URL="${env_livy_url:-${LIVY_URL:-}}"

require_cmd hdfs spark-submit
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }
skip() { echo "[SKIP] $*"; }

WS_USER="${WORKSHOP_USER:-${USER}}"
USER_HOME="${WORKSHOP_HOME}"
LIVY_LAB="${WORKSHOP_ROOT}/09-livy"
SESSION_OUT="${USER_HOME}/livy-curated"
BATCH_OUT="${USER_HOME}/livy-batch-curated"
TABLE_DIR="/warehouse/tablespace/external/hive/${WS_USER}.db/livy_curated_join"
EXPECTED_JOINED=24

expect_path() {
  if hdfs dfs -test -e "$1" 2>/dev/null; then pass "$2"; else fail_msg "$2 — $3"; fi
}

expect_path "${LIVY_LAB}/assets/spark_cleanse_join.py" \
  "Shared batch script on HDFS" \
  "ask your instructor to run the module setup"

expect_path "${SESSION_OUT}/_SUCCESS" \
  "Session output (_SUCCESS)" \
  "redo lab section 3"

expect_path "${BATCH_OUT}/_SUCCESS" \
  "Batch output (_SUCCESS)" \
  "redo lab section 5"

expect_path "${TABLE_DIR}" \
  "Table livy_curated_join in database ${WS_USER}" \
  "redo lab section 6"

count_py="$(mktemp)"
trap 'rm -f "${count_py}"' EXIT
cat > "${count_py}" <<'PY'
import sys
from pyspark.sql import SparkSession

path = sys.argv[1]
spark = SparkSession.builder.appName("workshop-09-check").master("local[2]").getOrCreate()
print(spark.read.parquet(path).count())
spark.stop()
PY

count_parquet() {
  spark-submit --master 'local[2]' "${count_py}" "$1" 2>/dev/null | tail -1 || true
}

session_count="$(count_parquet "${SESSION_OUT}")"
if [[ "${session_count}" == "${EXPECTED_JOINED}" ]]; then
  pass "Session result has ${EXPECTED_JOINED} rows"
else
  fail_msg "Session result has '${session_count:-unknown}' rows, expected ${EXPECTED_JOINED} — redo lab section 3"
fi

batch_count="$(count_parquet "${BATCH_OUT}")"
if [[ "${batch_count}" == "${EXPECTED_JOINED}" ]]; then
  pass "Batch result has ${EXPECTED_JOINED} rows"
else
  fail_msg "Batch result has '${batch_count:-unknown}' rows, expected ${EXPECTED_JOINED} — redo lab section 5"
fi

# Livy checks need the LDAP password (export LDAP_PASSWORD, see lab section 0) and the URL from the handout.
if [[ -n "${LDAP_PASSWORD:-}" && -n "${LIVY_URL}" && "${LIVY_URL}" != *"<"* ]]; then
  code="$(curl -s -u "${WS_USER}:${LDAP_PASSWORD}" -o /dev/null -w '%{http_code}' "${LIVY_URL%/}/sessions" || true)"
  if [[ "${code}" == "200" ]]; then
    pass "Livy login works (HTTP 200)"
    leftover="$(curl -s -u "${WS_USER}:${LDAP_PASSWORD}" "${LIVY_URL%/}/sessions?from=0&size=500" \
      | python3 -c '
import json, sys
name = "livy-lab-" + sys.argv[1]
print(sum(1 for s in json.load(sys.stdin).get("sessions", []) if s.get("name") == name))
' "${WS_USER}" 2>/dev/null || echo "?")"
    if [[ "${leftover}" == "0" ]]; then
      pass "No open Livy session left"
    elif [[ "${leftover}" == "?" ]]; then
      skip "Could not read the Livy session list"
    else
      fail_msg "Your session livy-lab-${WS_USER} is still open — delete it as in lab section 4"
    fi
  else
    fail_msg "Livy answered HTTP ${code:-000} — check LIVY_URL and your password (lab section 0)"
  fi
else
  skip "Livy login not checked (export LIVY_URL and LDAP_PASSWORD as in lab section 0)"
fi

if hdfs dfs -test -e "${USER_HOME}/livy-nb-curated/_SUCCESS" 2>/dev/null; then
  pass "Notebook output present (section 7)"
else
  skip "Notebook output not found — section 7 runs on your laptop and is not required"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Livy lab self-check passed."
