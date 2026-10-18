#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_admin_hdfs_kinit
require_cmd hdfs awk

MODULE_ROOT="${WORKSHOP_ROOT}/03-hive"
LANDING="${MODULE_ROOT}/landing/landisgyr_by_station"
WORK="${MODULE_ROOT}/work"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -d "${WORK}"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"

parts="$(hdfs dfs -ls "${LANDING}" 2>/dev/null | grep -c 'station_id=' || true)"
if [[ "${parts}" -ge 3 ]]; then
  echo "[PASS] ${parts} station folders under ${LANDING}"
else
  echo "[FAIL] expected at least 3 station folders under ${LANDING}, found ${parts}"
  fail=1
fi

# station_id is dropped from the split files: 14 CSV columns -> 13
cols="$(hdfs dfs -cat "${LANDING}/station_id=TS-101/part-0000.csv" 2>/dev/null | head -1 | awk -F, '{print NF}')"
if [[ "${cols}" == "13" ]]; then
  echo "[PASS] split files have 13 columns (station_id only in the folder name)"
else
  echo "[FAIL] split file column count is '${cols:-missing}', expected 13"
  fail=1
fi

if hdfs dfs -getfacl "${WORK}" 2>/dev/null | grep -q 'user:hive:rwx'; then
  echo "[PASS] hive user has rwx ACL on ${WORK}"
else
  echo "[WARN] no hive ACL on ${WORK} - fine if HiveServer2 runs as the end user or Ranger grants hive access"
fi

echo "[INFO] Not checked here: Ranger Hive policies (database ws_*, URL access to ${WORKSHOP_ROOT}). See 00-setup/admin/ranger/README.md"

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "03-basics-hive setup verify complete."
