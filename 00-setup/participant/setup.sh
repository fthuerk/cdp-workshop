#!/usr/bin/env bash
# Self-service setup: upload the workshop data and module files into YOUR OWN HDFS home,
# using your own Kerberos ticket. Use this when no trainer/admin can run bootstrap.sh.
#
# Usage: setup.sh [--root HDFS_DIR] [--modules "02 03 04 05 07"] [--remove]
#   --root     workshop location on HDFS (default: /user/<kerberos user>/cdp_workshop)
#   --modules  module setup scripts to run after the data upload (default: all)
#   --remove   delete the workshop location again (and exit)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"

ROOT=""
MODULES="02 03 04 05 06 07"
REMOVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="${2:?--root needs a path}"; shift 2 ;;
    --modules) MODULES="${2:?--modules needs a list}"; shift 2 ;;
    --remove) REMOVE=1; shift ;;
    -h|--help) sed -n 2,9p "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) log_err "Unknown argument: $1 (try --help)"; exit 1 ;;
  esac
done

require_cmd hdfs klist
require_kerberos_ticket

# User name = Kerberos principal without instance and realm, lower case (alice/admin@REALM -> alice).
principal="$(klist 2>/dev/null | awk '/Default principal/ {print $3; exit}')"
WS_USER="${WORKSHOP_USER:-${principal%%[/@]*}}"
WS_USER="$(printf '%s' "${WS_USER}" | tr '[:upper:]' '[:lower:]')"   # HDFS home dirs are lower case
[[ -n "${WS_USER}" ]] || { log_err "Cannot determine the user from the Kerberos ticket (run klist)"; exit 1; }
ROOT="${ROOT:-/user/${WS_USER}/cdp_workshop}"
log_info "Kerberos principal ${principal} -> user ${WS_USER}, workshop location ${ROOT}"

if [[ "${REMOVE}" == "1" ]]; then
  [[ "${ROOT}" == "/" || "${ROOT}" == "/user" || "${ROOT}" == "/user/${WS_USER}" ]] \
    && { log_err "Refusing to remove ${ROOT}"; exit 1; }
  hdfs dfs -rm -r -f -skipTrash "${ROOT}"
  log_info "Removed ${ROOT}"
  exit 0
fi

# Write config.env (gitignored) so every module script and check.sh uses your location.
CFG="${REPO_ROOT}/config.env"
[[ -f "${CFG}" ]] && cp "${CFG}" "${CFG}.bak" && log_info "Existing config.env saved as config.env.bak"
sed -e "s|^WORKSHOP_ROOT=.*|WORKSHOP_ROOT=${ROOT}|" \
    -e "s|^WORKSHOP_LOCAL=.*|WORKSHOP_LOCAL=${REPO_ROOT}|" \
    "${REPO_ROOT}/config.env.example" > "${CFG}"
log_info "Wrote ${CFG} (WORKSHOP_ROOT=${ROOT})"

# Run the admin scripts with your own ticket; no admin rights are needed under your home.
export CDP_WORKSHOP_SKIP_ADMIN_KINIT=1

log_info "Uploading sample data"
"${REPO_ROOT}/00-setup/admin/bootstrap.sh" --skip-kinit

for m in ${MODULES}; do
  script="$(ls "${REPO_ROOT}/${m}"-*/setup/setup.sh 2>/dev/null | head -1 || true)"
  if [[ -z "${script}" ]]; then
    log_warn "No setup script for module ${m}, skipping"
    continue
  fi
  log_info "Module ${m} setup"
  "${script}" --skip-kinit
done

cat <<MSG

Done. Your workshop location is ${ROOT}
In every lab, use this instead of the default:

  export WORKSHOP_ROOT=${ROOT}

Limits of the self-service path: no HDFS space quota (module 02 quota exercise), and no Ranger
policies (the Ranger-based steps in modules 02, 04, 05, 06 and 07 depend on what your account may do).
MSG
