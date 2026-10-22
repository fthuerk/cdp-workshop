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
DATA="${MODULE_ROOT}/data"
SOURCE="${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
TARGET="${DATA}/sample-landisgyr-data.csv"

if ! hdfs dfs -test -e "${SOURCE}"; then
  log_err "Missing ${SOURCE} - run 00-setup/admin/bootstrap.sh first"
  exit 1
fi

hdfs dfs -mkdir -p "${DATA}"
hdfs dfs -cp -f "${SOURCE}" "${TARGET}"
hdfs dfs -chmod -R 755 "${MODULE_ROOT}"

log_info "Atlas lab sample CSV at ${TARGET}"
log_info "08-basics-atlas setup complete under ${MODULE_ROOT}"
log_warn "Ranger: workshop users need read on ${DATA} and Hive policies on personal databases - see 00-setup/admin/ranger/README.md"
