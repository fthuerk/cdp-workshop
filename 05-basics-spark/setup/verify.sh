#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/05-spark"
SCRIPT="${MODULE_ROOT}/assets/spark_cleanse_join.py"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${SCRIPT}"
check hdfs dfs -test -d "${MODULE_ROOT}/work"

for dataset in landisgyr/sample-landisgyr-data.csv \
  operator_weather/sample-operator-weather.csv \
  awattar/sample-awattar-prices.csv; do
  check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/${dataset}"
done

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "05-basics-spark setup verify complete."
