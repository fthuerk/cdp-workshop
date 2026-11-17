#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd kafka-topics kafka-console-consumer
require_kerberos_ticket

SHARED_TOPIC="grid-measurements"
CONF="$(mktemp)"
trap 'rm -f "${CONF}"' EXIT
write_kafka_client_config "${CONF}"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

describe="$(kafka-topics --bootstrap-server "${KAFKA_BOOTSTRAP}" --command-config "${CONF}" --describe --topic "${SHARED_TOPIC}" 2>/dev/null || true)"
check grep -q "PartitionCount" <<< "${describe}"

lines="$(kafka-console-consumer --bootstrap-server "${KAFKA_BOOTSTRAP}" --consumer.config "${CONF}" \
  --topic "${SHARED_TOPIC}" --from-beginning --max-messages 15 --timeout-ms 20000 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${lines}" == "15" ]]; then
  echo "[PASS] ${SHARED_TOPIC} holds the 15 sample messages"
else
  echo "[FAIL] ${SHARED_TOPIC} returned ${lines} messages, expected 15 (run teardown.sh and setup.sh to reload)"
  fail=1
fi

echo "[INFO] Not checked here: Ranger Kafka policies for workshop users (see 00-setup/admin/ranger/README.md)."

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "15-basics-kafka setup verify complete."
