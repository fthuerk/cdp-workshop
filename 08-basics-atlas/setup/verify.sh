#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/08-atlas"
TARGET="${MODULE_ROOT}/data/sample-landisgyr-data.csv"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${TARGET}"

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "08-basics-atlas setup verify complete."
