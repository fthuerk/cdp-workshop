#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs dd

MODULE_ROOT="${WORKSHOP_ROOT}/02-hdfs"
LAB="${MODULE_ROOT}/lab"
PUBLIC="${MODULE_ROOT}/public"
QUOTA="${MODULE_ROOT}/quota_reached"
SECRET="${MODULE_ROOT}/secret"

hdfs dfs -mkdir -p "${LAB}" "${PUBLIC}" "${QUOTA}" "${SECRET}"

printf 'workshop dummy file for trash exercise\n' | hdfs dfs -put -f - "${LAB}/dummy.txt"

log_info "Creating 192 MB file (two blocks at 128 MB block size)"
dd if=/dev/zero bs=1M count=192 2>/dev/null | hdfs dfs -put -f - "${LAB}/bigfile_192mb.bin"

printf 'Do not share — workshop secret marker\n' | hdfs dfs -put -f - "${SECRET}/secret.txt"

# Space quota below one 128 MB block × replication so uploads fail predictably
hdfs dfsadmin -clrSpaceQuota "${QUOTA}" 2>/dev/null || true
hdfs dfsadmin -setSpaceQuota 1m "${QUOTA}" \
  || log_warn "Could not set space quota (needs HDFS superuser); the quota_reached exercise will not fail as described"

# POSIX baseline (Ranger optional)
hdfs dfs -chmod 755 "${MODULE_ROOT}" "${LAB}" 2>/dev/null || true
hdfs dfs -chmod 1777 "${PUBLIC}" 2>/dev/null || hdfs dfs -chmod 777 "${PUBLIC}"
hdfs dfs -chmod 700 "${SECRET}"
hdfs dfs -chmod 755 "${QUOTA}"

if [[ -n "${WORKSHOP_GROUP:-}" ]]; then
  hdfs dfs -chgrp "${WORKSHOP_GROUP}" "${PUBLIC}" 2>/dev/null || true
  hdfs dfs -chmod 775 "${PUBLIC}" 2>/dev/null || true
fi

log_info "HDFS module setup complete under ${MODULE_ROOT}"
