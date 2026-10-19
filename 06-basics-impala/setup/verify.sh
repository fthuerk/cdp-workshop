#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs awk

MODULE_ROOT="${WORKSHOP_ROOT}/06-impala"
SCALED_FILE="${MODULE_ROOT}/scaled/meter-15k.csv"
WORK="${MODULE_ROOT}/work"
REPEAT=1000

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${SCALED_FILE}"
check hdfs dfs -test -d "${WORK}"

source="${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
if hdfs dfs -test -e "${source}"; then
  echo "[PASS] source sample at ${source}"
else
  echo "[FAIL] missing ${source}"
  fail=1
fi

lines="$(hdfs dfs -cat "${SCALED_FILE}" 2>/dev/null | wc -l | tr -d ' ')"
body="$(hdfs dfs -cat "${source}" 2>/dev/null | awk 'NR > 1 && NF > 0' | wc -l | tr -d ' ')"
expected=$(( body * REPEAT + 1 ))
if [[ "${lines}" == "${expected}" ]]; then
  echo "[PASS] scaled file has ${lines} lines (1 header + ${body} x ${REPEAT})"
else
  echo "[FAIL] scaled file line count is ${lines:-missing}, expected ${expected}"
  fail=1
fi

if hdfs dfs -getfacl "${WORK}" 2>/dev/null | grep -q 'user:hive:rwx'; then
  echo "[PASS] hive user has rwx ACL on ${WORK}"
else
  echo "[WARN] no hive ACL on ${WORK} - fine if engines run as the end user or Ranger grants hive access"
fi

echo "[INFO] Not checked here: Impala daemon reachability or Ranger Impala/Hive policies."

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "06-basics-impala setup verify complete."
