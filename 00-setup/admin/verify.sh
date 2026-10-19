#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

fail=0
check() {
  if "$@"; then
    echo "[PASS] $*"
  else
    echo "[FAIL] $*"
    fail=1
  fi
}

check hdfs dfs -test -e "${WORKSHOP_ROOT}/.bootstrap/status"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"

rows="$(hdfs dfs -cat "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${rows}" -ge 2 ]]; then
  echo "[PASS] landisgyr CSV has data rows (lines=${rows})"
else
  echo "[FAIL] landisgyr CSV appears empty"
  fail=1
fi

if [[ ${fail} -ne 0 ]]; then
  exit 1
fi
echo "00-setup verify complete."
