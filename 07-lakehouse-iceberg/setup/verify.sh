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

check hdfs dfs -test -d /warehouse/tablespace/external/hive
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv"
check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"

echo "[INFO] Not checked here: Ranger policies (Hive/HDFS for ws_*, and the Iceberg storage handler policy: storage-type iceberg, storage-url *, RW Storage). Runtime version for Impala UPDATE/MERGE (7.3.1.500 or later). See 00-setup/admin/ranger/README.md"
echo "[INFO] Quick functional test as a normal participant: run lab section 2 (CREATE ... STORED AS ICEBERG) and section 3 (UPDATE, DELETE, MERGE) in the Hue Impala editor once."

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "07-lakehouse-iceberg setup verify complete."
