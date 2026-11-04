#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
env_livy_url="${LIVY_URL:-}"   # an exported LIVY_URL wins over config.env
parse_workshop_admin_args "$@"
load_config
LIVY_URL="${env_livy_url:-${LIVY_URL:-}}"

require_admin_hdfs_kinit
require_cmd hdfs curl

MODULE_ROOT="${WORKSHOP_ROOT}/09-livy"
SCRIPT="${MODULE_ROOT}/assets/spark_cleanse_join.py"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${SCRIPT}"
check hdfs dfs -test -d "${MODULE_ROOT}/work"

for dataset in landisgyr/sample-landisgyr-data.csv \
  operator_weather/sample-operator-weather.csv \
  awattar/sample-awattar-prices.csv; do
  check hdfs dfs -test -e "${WORKSHOP_ROOT}/data/${dataset}"
done

# Livy behind Knox: without credentials the gateway answers 401; a 200 also proves the route works.
# Anything else (000, 404, 503) means wrong URL, Knox topology without the Livy service, or Livy down.
if [[ -n "${LIVY_URL}" && "${LIVY_URL}" != *"<"* ]]; then
  code="$(curl -s -o /dev/null -w '%{http_code}' ${LIVY_CACERT:+--cacert "${LIVY_CACERT}"} "${LIVY_URL%/}/sessions" || true)"
  if [[ "${code}" == "401" || "${code}" == "200" ]]; then
    echo "[PASS] Livy endpoint answers (HTTP ${code}): ${LIVY_URL}"
  else
    echo "[FAIL] Livy endpoint ${LIVY_URL} returned HTTP ${code} (expected 401 or 200)"; fail=1
  fi
else
  echo "[WARN] LIVY_URL not set (config.env or environment) — Livy endpoint not checked"
fi

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "09-basics-livy setup verify complete."
