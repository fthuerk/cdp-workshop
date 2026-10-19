#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd hdfs
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
USER_HOME="/user/${WS_USER}"
HDFS_LAB="${WORKSHOP_ROOT}/02-hdfs/lab"

if hdfs dfs -test -d "${USER_HOME}" 2>/dev/null; then
  pass "Home directory exists: ${USER_HOME}"
else
  fail_msg "Missing ${USER_HOME} — complete lab section 2"
fi

if hdfs dfs -test -e "${USER_HOME}/sample-landisgyr-data.csv" 2>/dev/null; then
  pass "Landis&Gyr copy in home"
else
  fail_msg "Missing ${USER_HOME}/sample-landisgyr-data.csv"
fi

if hdfs dfs -test -e "${USER_HOME}/hosts" 2>/dev/null; then
  pass "hosts file present (trash exercise)"
else
  fail_msg "Missing ${USER_HOME}/hosts — redo trash restore or section 2"
fi

if hdfs dfs -test -e "${HDFS_LAB}/bigfile_192mb.bin" 2>/dev/null; then
  pass "Shared big file available for block exercise"
else
  fail_msg "Missing ${HDFS_LAB}/bigfile_192mb.bin — ask trainer to run setup"
fi

if hdfs dfs -cat "${WORKSHOP_ROOT}/02-hdfs/secret/secret.txt" >/dev/null 2>&1; then
  fail_msg "You can read secret.txt — security demo failed; tell trainer"
else
  pass "Cannot read secret.txt (expected)"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "HDFS lab self-check passed."
