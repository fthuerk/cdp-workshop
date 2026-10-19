#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
parse_workshop_admin_args "$@"
load_config

require_admin_hdfs_kinit
require_cmd hdfs yarn

MODULE_ROOT="${WORKSHOP_ROOT}/03-yarn"
ASSETS="${MODULE_ROOT}/assets"

fail=0
check() { if "$@"; then echo "[PASS] $*"; else echo "[FAIL] $*"; fail=1; fi }

check hdfs dfs -test -e "${ASSETS}/spark_linecount.py"
check hdfs dfs -test -e "${MODULE_ROOT}/input/die-verwandlung-kapitel-1.txt"
check hdfs dfs -test -e "${MODULE_ROOT}/input-many/part-000"

for jar in \
  /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  /opt/cloudera/parcels/CDH/lib/tez/bin/tez-examples-*.jar; do
  if compgen -G "${jar}" >/dev/null; then
    echo "[PASS] example JAR on edge node: ${jar}"
  else
    echo "[FAIL] example JAR not found on edge node: ${jar} — adjust the path in lab/lab_basics_yarn.md"
    fail=1
  fi
done

if yarn node -list 2>/dev/null | grep -q RUNNING; then
  echo "[PASS] yarn node -list shows RUNNING nodes"
else
  echo "[WARN] yarn node -list did not show RUNNING nodes — check YARN health"
fi

if [[ ${fail} -ne 0 ]]; then exit 1; fi
echo "03-basics-yarn setup verify complete."
