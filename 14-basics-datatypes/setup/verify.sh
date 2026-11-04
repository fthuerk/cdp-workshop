#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

EDGE_FILE="${WORKSHOP_ROOT}/14-datatypes/edge/edge-values.csv"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${EDGE_FILE}"

lines="$(hdfs dfs -cat "${EDGE_FILE}" 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${lines}" == "7" ]]; then
  echo "[PASS] edge file has ${lines} lines (1 header + 6 rows)"
else
  echo "[FAIL] edge file line count is ${lines:-missing}, expected 7"
  fail=1
fi

echo "[INFO] Not checked here: Impala/Spark reachability or Ranger policies."

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "14-basics-datatypes setup verify complete."
