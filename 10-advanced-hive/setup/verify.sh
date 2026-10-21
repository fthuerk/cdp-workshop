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
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"
check hdfs dfs -test -d /warehouse/tablespace/external/hive

echo "[INFO] Not checked here: Ranger policies for ws_* (see 00-setup/admin/ranger/README.md)"

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "10-advanced-hive setup verify complete."
