#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs awk mktemp

MODULE_ROOT="${WORKSHOP_ROOT}/05-impala"
SCALED="${MODULE_ROOT}/scaled"
SOURCE="${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
SCALED_FILE="${SCALED}/meter-15k.csv"
# Repeat the sample body so aggregation queries take long enough to compare Hive vs Impala.
REPEAT=1000

if ! hdfs dfs -test -e "${SOURCE}"; then
  log_err "Missing ${SOURCE} - run 00-setup/admin/bootstrap.sh first"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

hdfs dfs -cat "${SOURCE}" > "${tmp}/source.csv"
head -1 "${tmp}/source.csv" > "${tmp}/scaled.csv"
awk -F, 'NR > 1 && NF > 0 {print}' "${tmp}/source.csv" > "${tmp}/body.csv"
body_lines="$(wc -l < "${tmp}/body.csv" | tr -d ' ')"
if [[ "${body_lines}" -lt 1 ]]; then
  log_err "No data rows in ${SOURCE}"
  exit 1
fi

for ((i = 0; i < REPEAT; i++)); do
  cat "${tmp}/body.csv" >> "${tmp}/scaled.csv"
done

hdfs dfs -mkdir -p "${SCALED}"
hdfs dfs -put -f "${tmp}/scaled.csv" "${SCALED_FILE}"
hdfs dfs -chmod 755 "${MODULE_ROOT}"
hdfs dfs -chmod -R 755 "${SCALED}"

total_rows=$(( body_lines * REPEAT ))
log_info "Scaled meter file: ${total_rows} data rows at ${SCALED_FILE}"
log_info "Impala module setup complete under ${MODULE_ROOT}"
log_warn "Ranger: workshop users need Hive/Impala policies on ws_* and HDFS access to /warehouse/tablespace/external/hive/ws_* (default locations, no URL policy) - see 00-setup/admin/ranger/README.md (module 05)"
