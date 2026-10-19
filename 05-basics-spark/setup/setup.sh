#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/05-spark"
ASSETS="${MODULE_ROOT}/assets"
WORK="${MODULE_ROOT}/work"
LOCAL_ASSETS="${WORKSHOP_LOCAL}/05-basics-spark/assets"

for dataset in \
  "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" \
  "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv" \
  "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"; do
  if ! hdfs dfs -test -e "${dataset}"; then
    log_err "Missing ${dataset} — run 00-setup/admin/bootstrap.sh first"
    exit 1
  fi
done

if [[ ! -f "${LOCAL_ASSETS}/spark_cleanse_join.py" ]]; then
  log_err "Missing ${LOCAL_ASSETS}/spark_cleanse_join.py — set WORKSHOP_LOCAL to the repo on the edge node"
  exit 1
fi

hdfs dfs -mkdir -p "${ASSETS}" "${WORK}"
hdfs dfs -put -f "${LOCAL_ASSETS}/spark_cleanse_join.py" "${ASSETS}/spark_cleanse_join.py"
hdfs dfs -chmod 755 "${MODULE_ROOT}" 2>/dev/null || true
hdfs dfs -chmod -R 755 "${ASSETS}" 2>/dev/null || true
hdfs dfs -chmod 1777 "${WORK}" 2>/dev/null || true

log_info "Spark module setup complete under ${MODULE_ROOT}"
log_warn "Ranger: workshop users need Hive policies on ws_* and HDFS write on /user/<participant> — see 00-setup/admin/ranger/README.md (module 05)"
