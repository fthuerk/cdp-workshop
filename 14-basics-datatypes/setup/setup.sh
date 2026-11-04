#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs mktemp

MODULE_ROOT="${WORKSHOP_ROOT}/14-datatypes"
EDGE="${MODULE_ROOT}/edge"
EDGE_FILE="${EDGE}/edge-values.csv"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# Six rows of raw text, all columns read as STRING by the lab. The values are chosen
# so that Hive, Impala and Spark may disagree: overflow, invalid numbers, odd timestamp
# formats, a non-existent date, a DST gap, boolean spellings, umlauts, empty vs 'NULL'.
cat > "${tmp}/edge-values.csv" <<'EOF'
row_id,raw_int,raw_dec,raw_ts,raw_flag,raw_text
1,42,12.345,2026-01-15 08:00:00,true,Trafostation Süd
2,300,0.1,2026-01-15T08:00:00Z,TRUE,Trafostation Nord
3,2147483648,1234567890123.456,15.01.2026 08:00,yes,Umspannwerk Ost
4,abc,1e3,2026-02-30 10:00:00,1,
5,-7,-0.005,1970-01-01 00:00:00,false,NULL
6,0007,.5,2026-03-29 02:30:00,0,Straße
EOF

hdfs dfs -mkdir -p "${EDGE}"
hdfs dfs -put -f "${tmp}/edge-values.csv" "${EDGE_FILE}"
hdfs dfs -chmod 755 "${MODULE_ROOT}"
hdfs dfs -chmod -R 755 "${EDGE}"

log_info "Edge-value file (6 data rows) at ${EDGE_FILE}"
log_info "Data types module setup complete under ${MODULE_ROOT}"
log_warn "Ranger: same policies as module 05 (Hive/Impala/Spark on {USER}, default external warehouse access, no URL policy) - see 00-setup/admin/ranger/README.md (module 14)"
