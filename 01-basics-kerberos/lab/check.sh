#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd hdfs klist
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"

principal="$(klist 2>/dev/null | awk '/Default principal/ {print $3; exit}')"
if [[ "${principal}" == "${WS_USER}@"* ]]; then
  pass "Ticket belongs to ${principal}"
else
  fail_msg "Ticket is for '${principal}', expected ${WS_USER} — run kinit \"${WS_USER}\" (sections 3 and 7)"
fi

if [[ -z "${KRB5CCNAME:-}" ]]; then
  pass "KRB5CCNAME is not set (default ticket cache)"
else
  fail_msg "KRB5CCNAME is still set (${KRB5CCNAME}) — run unset KRB5CCNAME (section 5)"
fi

if [[ -e "/tmp/krb5cc_${WS_USER}_lab" ]]; then
  fail_msg "Custom cache /tmp/krb5cc_${WS_USER}_lab still exists — clean up (section 5)"
else
  pass "Custom ticket cache cleaned up"
fi

if hdfs dfs -ls "${WORKSHOP_ROOT}/data" >/dev/null 2>&1; then
  pass "HDFS access works with your ticket"
else
  fail_msg "Cannot list ${WORKSHOP_ROOT}/data — see lab/troubleshooting.md"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Kerberos lab self-check passed."
