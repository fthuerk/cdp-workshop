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
LOCAL_ASSETS="${WORKSHOP_LOCAL}/11-advanced-oozie/assets"

for dataset in landisgyr/sample-landisgyr-data.csv operator_weather/sample-operator-weather.csv; do
  if ! hdfs dfs -test -e "${WORKSHOP_ROOT}/data/${dataset}"; then
    log_err "Missing ${WORKSHOP_ROOT}/data/${dataset} — run 00-setup/admin/bootstrap.sh first"
    exit 1
  fi
done

if [[ ! -d "${LOCAL_ASSETS}/apps" ]]; then
  log_err "Missing ${LOCAL_ASSETS}/apps — set WORKSHOP_LOCAL to the repo on the edge node"
  exit 1
fi

# Shared, read-only templates: participants copy them into their own home directory.
hdfs dfs -rm -r -f -skipTrash "${MODULE_ROOT}/apps"
hdfs dfs -mkdir -p "${MODULE_ROOT}/apps"
for app in "${LOCAL_ASSETS}"/apps/*/; do
  name="$(basename "${app}")"
  hdfs dfs -mkdir -p "${MODULE_ROOT}/apps/${name}"
  hdfs dfs -put -f "${app}"* "${MODULE_ROOT}/apps/${name}/"
done

# The same script lives in two apps: one source file in the repo, copied here.
for app in hive-summary meter-daily; do
  hdfs dfs -put -f "${LOCAL_ASSETS}/common/station_summary.q" "${MODULE_ROOT}/apps/${app}/"
done
for app in spark-weather meter-daily; do
  hdfs dfs -mkdir -p "${MODULE_ROOT}/apps/${app}/lib"
  hdfs dfs -put -f "${LOCAL_ASSETS}/common/weather_daily.py" "${MODULE_ROOT}/apps/${app}/lib/"
done

# Coordinator definitions (the workflow they start is the participant's own copy)
hdfs dfs -rm -r -f -skipTrash "${MODULE_ROOT}/coord"
hdfs dfs -mkdir -p "${MODULE_ROOT}/coord"
for coord in "${LOCAL_ASSETS}"/coord/*/; do
  name="$(basename "${coord}")"
  hdfs dfs -mkdir -p "${MODULE_ROOT}/coord/${name}"
  hdfs dfs -put -f "${coord}"* "${MODULE_ROOT}/coord/${name}/"
done

hdfs dfs -chmod -R 755 "${MODULE_ROOT}"

log_info "Oozie module setup complete under ${MODULE_ROOT}"
log_warn "Check the platform side with 11-advanced-oozie/setup/verify.sh (Oozie URL, ShareLib, hive2 credential)."
log_warn "Ranger: same Hive {USER} pattern as module 04; Oozie runs actions as the participant (proxy user)."
