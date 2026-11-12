#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/11-oozie"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

for f in \
  apps/landing-check/workflow.xml \
  apps/hive-summary/workflow.xml apps/hive-summary/station_summary.hql \
  apps/spark-weather/workflow.xml apps/spark-weather/lib/weather_daily.py \
  apps/meter-daily/workflow.xml apps/meter-daily/station_summary.hql apps/meter-daily/lib/weather_daily.py \
  coord/landing-check-coord/coordinator.xml coord/meter-daily-coord/coordinator.xml; do
  check hdfs dfs -test -e "${MODULE_ROOT}/${f}"
done

# Oozie behind Knox takes user name and password: export WORKSHOP_USER and WORKSHOP_PASSWORD before running this script.
if [[ -n "${WORKSHOP_PASSWORD:-}" ]]; then
  oozie() { command oozie "$@" -auth BASIC -username "${WORKSHOP_USER:-${USER}}" -password "${WORKSHOP_PASSWORD}"; }
fi

# Platform side: needs OOZIE_URL (config.env or environment) and the oozie client on this host.
if [[ -n "${OOZIE_URL:-}" ]] && command -v oozie >/dev/null 2>&1; then
  export OOZIE_URL
  if oozie admin -status | grep -q NORMAL; then echo "[PASS] Oozie server status NORMAL"; else echo "[FAIL] Oozie server not NORMAL"; fail=1; fi
  libs="$(oozie admin -shareliblist)"
  for lib in oozie hive2 spark3; do
    if echo "${libs}" | grep -qx "${lib}"; then echo "[PASS] ShareLib '${lib}' installed"; else echo "[FAIL] ShareLib '${lib}' missing (Cloudera Manager: Oozie > Actions > Install Oozie ShareLib)"; fail=1; fi
  done
else
  echo "[WARN] OOZIE_URL not set or oozie client missing: ShareLib and server status not checked"
fi

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "11-advanced-oozie setup verify complete."
