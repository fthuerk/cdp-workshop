#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARTICIPANT_KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-}"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config
KAFKA_BOOTSTRAP="${PARTICIPANT_KAFKA_BOOTSTRAP}"
require_cmd kafka-topics kafka-configs kafka-consumer-groups
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
KAFKA_CONF="${KAFKA_CONF:-/tmp/kafka-client.${WS_USER}.properties}"
TOPIC="${KAFKA_TOPIC:-${WS_USER}}"
GROUP="${KAFKA_GROUP:-${WS_USER}}"
SHARED="${KAFKA_SHARED:-grid-measurements}"

if [[ -z "${KAFKA_BOOTSTRAP}" ]]; then
  fail_msg "KAFKA_BOOTSTRAP is not set - export the variables of the lab setup block"
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi

ADMIN=(--bootstrap-server "${KAFKA_BOOTSTRAP}" --command-config "${KAFKA_CONF}")

if [[ -f "${KAFKA_CONF}" ]] && grep -q '^security.protocol=SASL_SSL' "${KAFKA_CONF}" \
   && grep -q 'sasl.kerberos.service.name=kafka' "${KAFKA_CONF}"; then
  pass "client settings file ${KAFKA_CONF}"
else
  fail_msg "Missing or incomplete ${KAFKA_CONF} - redo lab section 0"
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi

# Section 1: topic with at least 3 partitions
partitions="$(kafka-topics "${ADMIN[@]}" --describe --topic "${TOPIC}" 2>/dev/null \
  | grep -o 'PartitionCount:[[:space:]]*[0-9]*' | grep -o '[0-9]*$' || true)"
if [[ -n "${partitions}" && "${partitions}" -ge 3 ]]; then
  pass "topic ${TOPIC} has ${partitions} partitions"
else
  fail_msg "Topic ${TOPIC} missing or has fewer than 3 partitions (got '${partitions:-nothing}') - lab section 1"
fi

# Sections 2 and 3: 1 + 15 + 5 messages (sum of the end offsets, read from the group description)
group_out="$(kafka-consumer-groups "${ADMIN[@]}" --describe --group "${GROUP}" 2>/dev/null || true)"
end_sum="$(awk -v t="${TOPIC}" '$2 == t {s += $5} END {print s + 0}' <<< "${group_out}")"
if [[ "${end_sum}" -ge 21 ]]; then
  pass "consumer group ${GROUP} exists, topic holds ${end_sum} messages"
else
  fail_msg "Expected at least 21 messages and group ${GROUP} (got ${end_sum}) - lab sections 2 and 3"
fi

# Section 5: retention override
if kafka-configs "${ADMIN[@]}" --describe --entity-type topics --entity-name "${TOPIC}" 2>/dev/null | grep -q 'retention.ms=3600000'; then
  pass "retention.ms=3600000 on ${TOPIC}"
else
  fail_msg "retention.ms=3600000 not set on ${TOPIC} - lab section 5"
fi

# Section 6: shared topic visible (the lab read it with your group, so do not read it again here)
if kafka-topics "${ADMIN[@]}" --describe --topic "${SHARED}" 2>/dev/null | grep -q 'PartitionCount'; then
  pass "shared topic ${SHARED} is visible"
else
  fail_msg "Cannot describe ${SHARED} - ask your instructor to check the topic and the Ranger policy"
fi

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Kafka lab self-check passed."
