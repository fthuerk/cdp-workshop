#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

# Kafka admin: kinit as a user with all Kafka permissions in Ranger (or as the kafka service principal) before running this.
require_cmd kafka-topics kafka-console-producer awk
require_kerberos_ticket

SHARED_TOPIC="grid-measurements"
SAMPLE="${WORKSHOP_LOCAL}/data/samples/sample-grid-measurements.csv"
CONF="$(mktemp)"
trap 'rm -f "${CONF}"' EXIT
write_kafka_client_config "${CONF}"

if [[ ! -f "${SAMPLE}" ]]; then
  log_err "Missing ${SAMPLE} (set WORKSHOP_LOCAL to this repo)"
  exit 1
fi

if kafka-topics --bootstrap-server "${KAFKA_BOOTSTRAP}" --command-config "${CONF}" --describe --topic "${SHARED_TOPIC}" >/dev/null 2>&1; then
  log_info "Topic ${SHARED_TOPIC} exists; not loading it again (run teardown.sh first to reload)"
  exit 0
fi

kafka-topics --bootstrap-server "${KAFKA_BOOTSTRAP}" --command-config "${CONF}" \
  --create --topic "${SHARED_TOPIC}" --partitions 3 --replication-factor "${WORKSHOP_REPLICATION:-3}"

# Key = station_id (second CSV column), value = the CSV line; header removed
tail -n +2 "${SAMPLE}" \
  | awk -F, '{print $2 "|" $0}' \
  | kafka-console-producer --bootstrap-server "${KAFKA_BOOTSTRAP}" --producer.config "${CONF}" --producer-property enable.idempotence=false \
      --topic "${SHARED_TOPIC}" --property parse.key=true --property "key.separator=|"

log_info "Loaded ${SHARED_TOPIC} with the grid measurement sample"
log_warn "Ranger (Kafka service): workshop users need the policies listed for module 15 in 00-setup/admin/ranger/README.md"
