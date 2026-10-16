#!/usr/bin/env bash
# Trainer demonstrations — run on edge node with appropriate credentials.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd hdfs

MODULE_ROOT="${WORKSHOP_ROOT}/01-hdfs"
QUOTA="${MODULE_ROOT}/quota_reached"
SECRET="${MODULE_ROOT}/secret"
LAB="${MODULE_ROOT}/lab"

echo "=== Demo: read secret (expect failure for participants) ==="
hdfs dfs -cat "${SECRET}/secret.txt" || echo "(failed as expected for non-admin users)"

echo "=== Demo: space quota on quota_reached ==="
hdfs dfs -count -q "${QUOTA}" || true
echo "Attempting upload (expect quota violation):"
hdfs dfs -put -f /etc/hosts "${QUOTA}/hosts-quota-test" || echo "(upload failed as expected)"

echo "=== Demo: snapshot restore (admin / superuser only) ==="
if hdfs dfsadmin -allowSnapshot "${LAB}" 2>/dev/null; then
  hdfs dfs -createSnapshot "${LAB}" "demo-snap-$(date +%H%M)" || true
  hdfs dfs -ls "${LAB}/.snapshot" 2>/dev/null || hdfs dfs -ls "${LAB}/.snapshots" 2>/dev/null || true
  echo "Restore flow: delete dummy.txt, copy from snapshot path shown above"
else
  echo "Snapshots not enabled or insufficient privileges — skip live snapshot demo"
fi

echo "Demos complete."
