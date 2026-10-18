#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_admin_hdfs_kinit
require_cmd hdfs yarn

MODULE_ROOT="${WORKSHOP_ROOT}/02-yarn"
ASSETS="${MODULE_ROOT}/assets"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${ASSETS}/spark_linecount.py"

if yarn node -list 2>/dev/null | grep -q RUNNING; then
  echo "[PASS] yarn node -list shows RUNNING nodes"
else
  echo "[WARN] yarn node -list did not show RUNNING nodes — check YARN health"
fi

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "02-basics-yarn setup verify complete."
