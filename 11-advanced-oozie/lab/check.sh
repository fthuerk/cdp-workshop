#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARTICIPANT_OOZIE_URL="${OOZIE_URL:-}"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config
OOZIE_URL="${PARTICIPANT_OOZIE_URL:-${OOZIE_URL:-}}"

require_cmd hdfs oozie
require_kerberos_ticket

if [[ -z "${OOZIE_URL}" ]]; then
  log_err "OOZIE_URL is not set. Export it first (lab section 1)."
  exit 1
fi
export OOZIE_URL

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"

# Oozie behind Knox takes user name and password (HTTP Basic); lab section 1 exports WORKSHOP_PASSWORD
if [[ -n "${WORKSHOP_PASSWORD:-}" ]]; then
  oozie() { command oozie "$@" -auth BASIC -username "${WS_USER}" -password "${WORKSHOP_PASSWORD}"; }
else
  echo "[WARN] WORKSHOP_PASSWORD is not set: oozie commands use no login (needed when Oozie is behind Knox, lab section 1)"
fi
OOZIE_HDFS="/user/${WS_USER}/oozie"

# count_jobs <wf|coordinator> <app name> [status]
count_jobs() {
  local filter="user=${WS_USER};name=$2"
  [[ -n "${3:-}" ]] && filter="${filter};status=$3"
  oozie jobs -jobtype "$1" -filter "${filter}" -len 100 | grep -c 'oozie-oozi-[WC]' || true
}

check_wf() {  # name status section
  local n
  n="$(count_jobs wf "$1" "$2")"
  if [[ "${n}" -ge 1 ]]; then pass "workflow ${1}: ${n} job(s) ${2}"; else fail_msg "no ${2} job of workflow ${1} — redo lab section ${3}"; fi
}

check_wf hello-wf SUCCEEDED 2
check_wf landing-check-wf SUCCEEDED 3
check_wf landing-check-wf KILLED 3
check_wf meter-hive-wf SUCCEEDED 4
check_wf meter-weather-wf SUCCEEDED 5
check_wf meter-daily-wf SUCCEEDED 6
check_wf csv-load-wf SUCCEEDED 10

for coord_name in landing-check-coord meter-daily-coord; do
  n="$(count_jobs coordinator "${coord_name}")"
  if [[ "${n}" -ge 1 ]]; then pass "coordinator ${coord_name} was submitted"; else fail_msg "coordinator ${coord_name} not found — redo lab section 7 or 8"; fi
done

if hdfs dfs -test -e "${OOZIE_HDFS}/out/weather_daily/2026-01-15/_SUCCESS" 2>/dev/null; then
  pass "Spark output present"
else
  fail_msg "Missing ${OOZIE_HDFS}/out/weather_daily/2026-01-15/_SUCCESS — redo lab section 5"
fi

if hdfs dfs -test -d "${OOZIE_HDFS}/work/landing-check-coord" 2>/dev/null; then
  pass "time-based coordinator created work folders"
else
  fail_msg "Missing ${OOZIE_HDFS}/work/landing-check-coord — redo lab section 7"
fi

running="$(oozie jobs -jobtype coordinator -filter "user=${WS_USER};status=RUNNING" -len 100 | grep -c 'oozie-oozi-C' || true)"
if [[ "${running}" -eq 0 ]]; then
  pass "no coordinator of yours is still running"
else
  fail_msg "${running} coordinator(s) still RUNNING — kill them (lab section 9)"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Oozie lab self-check passed."
