#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd klist hdfs
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

if hdfs dfs -test -d "${WORKSHOP_ROOT}" 2>/dev/null; then
  pass "WORKSHOP_ROOT exists: ${WORKSHOP_ROOT}"
else
  fail_msg "WORKSHOP_ROOT not found: ${WORKSHOP_ROOT} (ask trainer to run bootstrap)"
fi

if hdfs dfs -test -d "${WORKSHOP_ROOT}/data/landisgyr" 2>/dev/null; then
  pass "Sample dataset path exists: ${WORKSHOP_ROOT}/data/landisgyr"
else
  fail_msg "Missing ${WORKSHOP_ROOT}/data/landisgyr (bootstrap incomplete?)"
fi

if hdfs dfs -test -d "${WORKSHOP_HOME}" 2>/dev/null; then
  pass "Personal HDFS home exists: ${WORKSHOP_HOME}"
else
  echo "[WARN] ${WORKSHOP_HOME} not found — you will create it in module 02"
fi

if command -v beeline >/dev/null 2>&1; then
  pass "beeline available (Hive modules)"
else
  echo "[WARN] beeline not in PATH (Hive modules may need edge node profile)"
fi

if [[ ${fail} -ne 0 ]]; then
  exit 1
fi
echo "Environment check complete."
