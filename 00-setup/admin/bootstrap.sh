#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_admin_hdfs_kinit
require_cmd hdfs find awk

SAMPLES="${WORKSHOP_LOCAL}/data/samples"
if [[ ! -d "${SAMPLES}" ]]; then
  log_err "Sample directory not found: ${SAMPLES} (set WORKSHOP_LOCAL in config.env)"
  exit 1
fi

# dataset_folder:filename
DATASETS=(
  "landisgyr:sample-landisgyr-data.csv"
  "operator_weather:sample-operator-weather.csv"
  "awattar:sample-awattar-prices.csv"
  "energy_charts:sample-energy-charts.csv"
  "open_meteo:sample-open-meteo.csv"
  "geosphere:sample-geosphere-austria.csv"
  "basemap:sample-basemap-at-locations.csv"
  "openstreetmap:sample-openstreetmap-context.csv"
  "statistik_austria:sample-statistik-austria-context.csv"
  "holidays_data_gv_at:sample-data-gv-at-holidays.csv"
  "holidays_nager:sample-nager-date-holidays.csv"
)

log_info "Creating workshop root ${WORKSHOP_ROOT}"
hdfs dfs -mkdir -p "${WORKSHOP_ROOT}/data"

for entry in "${DATASETS[@]}"; do
  folder="${entry%%:*}"
  file="${entry#*:}"
  local_path="${SAMPLES}/${file}"
  hdfs_path="${WORKSHOP_ROOT}/data/${folder}"
  if [[ ! -f "${local_path}" ]]; then
    log_err "Missing local sample: ${local_path}"
    exit 1
  fi
  hdfs dfs -mkdir -p "${hdfs_path}"
  hdfs dfs -put -f "${local_path}" "${hdfs_path}/"
  log_info "Uploaded ${file} -> ${hdfs_path}/"
done

PARTICIPANTS_FILE="${REPO_ROOT}/00-setup/admin/participants.txt"
if [[ -f "${PARTICIPANTS_FILE}" ]]; then
  while IFS= read -r u || [[ -n "${u}" ]]; do
    [[ -z "${u}" || "${u}" =~ ^# ]] && continue
    hdfs dfs -mkdir -p "/user/${u}"
    hdfs dfs -chown "${u}:${u}" "/user/${u}" 2>/dev/null || hdfs dfs -chmod 755 "/user/${u}"
    log_info "Ensured /user/${u}"
  done < "${PARTICIPANTS_FILE}"
fi

# Marker for verify
hdfs dfs -mkdir -p "${WORKSHOP_ROOT}/.bootstrap"
echo "bootstrap_complete" | hdfs dfs -put -f - "${WORKSHOP_ROOT}/.bootstrap/status"

log_info "Bootstrap complete."
