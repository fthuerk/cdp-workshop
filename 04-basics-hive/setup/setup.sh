#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs awk sort mktemp

MODULE_ROOT="${WORKSHOP_ROOT}/04-hive"
LANDING="${MODULE_ROOT}/landing/landisgyr_by_station"
SOURCE="${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"

if ! hdfs dfs -test -e "${SOURCE}"; then
  log_err "Missing ${SOURCE} - run 00-setup/admin/bootstrap.sh first"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

hdfs dfs -cat "${SOURCE}" > "${tmp}/all.csv"

# One folder per station in Hive layout (station_id=<value>/). The station_id column is
# dropped from the rows: in a partitioned table the value lives in the directory name.
hdfs dfs -rm -r -skipTrash "${LANDING}" 2>/dev/null || true
for station in $(awk -F, 'NR > 1 && $2 != "" {print $2}' "${tmp}/all.csv" | sort -u); do
  awk -F, -v OFS=, -v s="${station}" \
    'NR > 1 && $2 == s {print $1,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14}' \
    "${tmp}/all.csv" > "${tmp}/${station}.csv"
  hdfs dfs -mkdir -p "${LANDING}/station_id=${station}"
  hdfs dfs -put -f "${tmp}/${station}.csv" "${LANDING}/station_id=${station}/part-0000.csv"
  log_info "Landing folder station_id=${station}"
done

hdfs dfs -chmod 755 "${MODULE_ROOT}"
hdfs dfs -chmod -R 755 "${MODULE_ROOT}/landing"

log_info "Hive module setup complete under ${MODULE_ROOT}"
# Participants create ws_<user> databases and tables with the default external location and copy
# files into /warehouse/tablespace/external/hive/ws_<user>.db/<table>. That needs Ranger policies.
log_warn "Ranger: workshop users need Hive and HDFS policies for ws_* - see 00-setup/admin/ranger/README.md (module 04)"
