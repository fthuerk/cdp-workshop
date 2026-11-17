#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd kafka-topics
require_kerberos_ticket

CONF="$(mktemp)"
trap 'rm -f "${CONF}"' EXIT
write_kafka_client_config "${CONF}"

kafka-topics --bootstrap-server "${KAFKA_BOOTSTRAP}" --command-config "${CONF}" --delete --if-exists --topic grid-measurements
log_info "Deleted topic grid-measurements (participant topics named like the users are left alone)"
