#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd hdfs yarn
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
USER_HOME="/user/${WS_USER}"
YARN_LAB="${WORKSHOP_ROOT}/03-yarn"

if hdfs dfs -test -e "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" 2>/dev/null; then
  pass "Shared input text available"
else
  fail_msg "Missing ${YARN_LAB}/input/die-verwandlung-kapitel-1.txt — ask your instructor"
fi

if hdfs dfs -test -e "${YARN_LAB}/assets/spark_linecount.py" 2>/dev/null; then
  pass "Shared Spark script available"
else
  fail_msg "Missing ${YARN_LAB}/assets/spark_linecount.py — ask your instructor"
fi

if hdfs dfs -test -e "${USER_HOME}/wordcount-mr/_SUCCESS" 2>/dev/null; then
  pass "MapReduce word count output"
else
  fail_msg "Missing ${USER_HOME}/wordcount-mr/_SUCCESS — redo lab section 3"
fi

if hdfs dfs -test -e "${USER_HOME}/wordcount-tez/_SUCCESS" 2>/dev/null; then
  pass "Tez word count output"
else
  fail_msg "Missing ${USER_HOME}/wordcount-tez/_SUCCESS — redo lab section 6"
fi

if hdfs dfs -test -e "${USER_HOME}/linecount-spark/_SUCCESS" 2>/dev/null; then
  pass "Spark line count output"
else
  fail_msg "Missing ${USER_HOME}/linecount-spark/_SUCCESS — redo lab section 8"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "YARN lab self-check passed."
