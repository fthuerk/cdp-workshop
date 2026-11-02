#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd beeline awk mktemp

: "${HS2_URL:?Set HS2_URL in config.env}"

PARTICIPANTS_FILE="${CDP_WORKSHOP_PARTICIPANTS:-${REPO_ROOT}/00-setup/admin/participants.txt}"
if [[ ! -f "${PARTICIPANTS_FILE}" ]]; then
  PARTICIPANTS_FILE="${REPO_ROOT}/00-setup/admin/participants.txt.example"
  log_warn "Using example participants file: ${PARTICIPANTS_FILE}"
fi

beeline_q() {
  beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
    -e "$1" 2>/dev/null || true
}

log_info "Creating ranger_lab database and tables (admin ticket: $(klist 2>/dev/null | awk '/Default principal/ {print $3; exit}'))"

beeline_q "CREATE DATABASE IF NOT EXISTS ranger_lab;"

beeline_q "DROP TABLE IF EXISTS ranger_lab.meter_readings;"
beeline_q "DROP TABLE IF EXISTS ranger_lab.customer_master;"
beeline_q "DROP TABLE IF EXISTS ranger_lab.station_assignment;"

beeline_q "
CREATE TABLE ranger_lab.meter_readings (
  ts_utc STRING,
  station_id STRING,
  device_id STRING,
  customer_name STRING,
  customer_email STRING,
  region STRING,
  active_power_kw DOUBLE
);"

beeline_q "
CREATE TABLE ranger_lab.customer_master (
  device_id STRING,
  customer_name STRING,
  iban_last4 STRING
);"

beeline_q "
CREATE TABLE ranger_lab.station_assignment (
  user_name STRING,
  station_id STRING
);"

# Synthetic meter readings (~30 rows, 4 stations)
beeline_q "
INSERT INTO ranger_lab.meter_readings VALUES
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0001', 'Alex Meter', 'alex.meter@example.com', 'North', 12.4),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0001', 'Alex Meter', 'alex.meter@example.com', 'North', 13.1),
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0002', 'Blake Grid', 'blake.grid@example.com', 'North', 8.7),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0002', 'Blake Grid', 'blake.grid@example.com', 'North', 9.2),
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0003', 'Casey Volt', 'casey.volt@example.com', 'North', 10.1),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0003', 'Casey Volt', 'casey.volt@example.com', 'North', 10.4),
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0004', 'Dana Amp', 'dana.amp@example.com', 'North', 11.0),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0004', 'Dana Amp', 'dana.amp@example.com', 'North', 11.3),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0101', 'Evan Load', 'evan.load@example.com', 'East', 14.2),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0101', 'Evan Load', 'evan.load@example.com', 'East', 14.8),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0102', 'Fran Peak', 'fran.peak@example.com', 'East', 16.1),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0102', 'Fran Peak', 'fran.peak@example.com', 'East', 15.9),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0103', 'Glen Sync', 'glen.sync@example.com', 'East', 13.5),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0103', 'Glen Sync', 'glen.sync@example.com', 'East', 13.7),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0104', 'Hope Line', 'hope.line@example.com', 'East', 12.9),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0104', 'Hope Line', 'hope.line@example.com', 'East', 13.0),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0201', 'Ivy Sub', 'ivy.sub@example.com', 'South', 21.5),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0201', 'Ivy Sub', 'ivy.sub@example.com', 'South', 20.9),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0202', 'Jade Ring', 'jade.ring@example.com', 'South', 22.3),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0202', 'Jade Ring', 'jade.ring@example.com', 'South', 22.0),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0203', 'Kai Feed', 'kai.feed@example.com', 'South', 19.8),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0203', 'Kai Feed', 'kai.feed@example.com', 'South', 20.1),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0204', 'Lane Bus', 'lane.bus@example.com', 'South', 18.6),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0204', 'Lane Bus', 'lane.bus@example.com', 'South', 18.9),
  ('2024-01-04 00:00:00', 'TS-401', 'DEV-0301', 'Morgan Tie', 'morgan.tie@example.com', 'West', 9.4),
  ('2024-01-04 00:15:00', 'TS-401', 'DEV-0301', 'Morgan Tie', 'morgan.tie@example.com', 'West', 9.6),
  ('2024-01-04 00:00:00', 'TS-401', 'DEV-0302', 'Noel Arc', 'noel.arc@example.com', 'West', 10.2),
  ('2024-01-04 00:15:00', 'TS-401', 'DEV-0302', 'Noel Arc', 'noel.arc@example.com', 'West', 10.5),
  ('2024-01-04 00:00:00', 'TS-401', 'DEV-0303', 'Owen Pole', 'owen.pole@example.com', 'West', 11.7),
  ('2024-01-04 00:15:00', 'TS-401', 'DEV-0303', 'Owen Pole', 'owen.pole@example.com', 'West', 11.9);"

beeline_q "
INSERT INTO ranger_lab.customer_master VALUES
  ('DEV-0001', 'Alex Meter', '4821'),
  ('DEV-0002', 'Blake Grid', '9033'),
  ('DEV-0101', 'Evan Load', '1144'),
  ('DEV-0201', 'Ivy Sub', '5560'),
  ('DEV-0301', 'Morgan Tie', '7782');"

# station_assignment: rotate users across four stations (1–2 stations per user)
stations=(TS-101 TS-102 TS-305 TS-401)
tmp_sql="$(mktemp)"
trap 'rm -f "${tmp_sql}"' EXIT
idx=0
while IFS= read -r user || [[ -n "${user}" ]]; do
  user="$(echo "${user}" | sed 's/#.*//' | tr -d '[:space:]')"
  [[ -z "${user}" ]] && continue
  s1="${stations[$(( idx % 4 ))]}"
  s2="${stations[$(( (idx + 1) % 4 ))]}"
  printf "INSERT INTO ranger_lab.station_assignment VALUES ('%s', '%s');\n" "${user}" "${s1}" >> "${tmp_sql}"
  printf "INSERT INTO ranger_lab.station_assignment VALUES ('%s', '%s');\n" "${user}" "${s2}" >> "${tmp_sql}"
  idx=$(( idx + 1 ))
done < "${PARTICIPANTS_FILE}"

while IFS= read -r stmt; do
  [[ -z "${stmt}" ]] && continue
  beeline_q "${stmt}"
done < "${tmp_sql}"

count="$(beeline_q 'SELECT COUNT(*) FROM ranger_lab.meter_readings;' | tail -1)"
log_info "ranger_lab.meter_readings row count: ${count:-unknown}"
log_info "Ranger module setup complete."
log_warn "Do not create Ranger policies yet — the trainer adds them live during the lab (see I2-basics-ranger/trainer/notes.md)."
log_warn "Ranger: after the lab, remove or disable workshop policies on ranger_lab if you reuse the cluster."
