#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd curl python3

: "${RANGER_URL:?Set RANGER_URL in config.env}"
: "${RANGER_USER:?Set RANGER_USER in config.env}"
: "${RANGER_PASSWORD:?Set RANGER_PASSWORD in config.env (never commit)}"
: "${RANGER_HDFS_SERVICE:?Set RANGER_HDFS_SERVICE in config.env}"

RANGER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_warn "Ranger REST import is environment-specific. Review JSON paths and service name before running."

for f in "${RANGER_DIR}"/policy-*.json; do
  body="$(WORKSHOP_ROOT="${WORKSHOP_ROOT}" RANGER_HDFS_SERVICE="${RANGER_HDFS_SERVICE}" python3 - "${f}" <<'PY'
import json, os, sys
p = sys.argv[1]
with open(p) as fh:
    doc = json.load(fh)
doc["service"] = os.environ.get("RANGER_HDFS_SERVICE", doc.get("service", "cm_hdfs"))
root = os.environ.get("WORKSHOP_ROOT", "/2026_cdp_workshop")
raw = json.dumps(doc)
raw = raw.replace("/2026_cdp_workshop", root)
print(raw)
PY
)"
  name="$(echo "${body}" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")"
  log_info "Posting policy: ${name}"
  http_code="$(curl -s -o /tmp/ranger_policy_resp.json -w "%{http_code}" \
    -u "${RANGER_USER}:${RANGER_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${RANGER_URL}/service/public/v2/api/policy" \
    -d "${body}")"
  if [[ "${http_code}" != "200" && "${http_code}" != "201" ]]; then
    log_err "Ranger API returned ${http_code} for ${name}; see /tmp/ranger_policy_resp.json"
    cat /tmp/ranger_policy_resp.json >&2
    exit 1
  fi
done

log_info "Ranger policies submitted. Confirm in Ranger UI."
