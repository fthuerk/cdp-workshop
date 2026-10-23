#!/usr/bin/env bash
# Shared helpers for cdp-workshop scripts.

set -euo pipefail

_ws_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ws_repo_root="$(cd "${_ws_script_dir}/.." && pwd)"

# Precedence: environment (WORKSHOP_ROOT, WORKSHOP_LOCAL, HS2_URL) > config.env > config.env.example.
load_config() {
  local cfg="${CDP_WORKSHOP_CONFIG:-${_ws_repo_root}/config.env}"
  local env_root="${WORKSHOP_ROOT:-}" env_local="${WORKSHOP_LOCAL:-}" env_hs2="${HS2_URL:-}"
  if [[ -f "${cfg}" ]]; then
    # shellcheck disable=SC1090
    source "${cfg}"
  elif [[ -f "${_ws_repo_root}/config.env.example" ]]; then
    # shellcheck disable=SC1090
    source "${_ws_repo_root}/config.env.example"
    log_warn "Using config.env.example; copy to config.env for production runs."
  else
    echo "No config.env or config.env.example found under ${_ws_repo_root}" >&2
    exit 1
  fi
  WORKSHOP_ROOT="${env_root:-${WORKSHOP_ROOT:-}}"
  WORKSHOP_LOCAL="${env_local:-${WORKSHOP_LOCAL:-${_ws_repo_root}}}"
  HS2_URL="${env_hs2:-${HS2_URL:-}}"
  [[ -d "${WORKSHOP_LOCAL}/data/samples" ]] || WORKSHOP_LOCAL="${_ws_repo_root}"   # not at the configured path: use this clone
  : "${WORKSHOP_ROOT:?WORKSHOP_ROOT must be set}"
  # Participant HDFS home for lab output; override for a different folder.
  WORKSHOP_USER="${WORKSHOP_USER:-${USER:-}}"
  WORKSHOP_HOME="${WORKSHOP_HOME:-/user/${WORKSHOP_USER}}"
  export WORKSHOP_ROOT WORKSHOP_LOCAL HS2_URL WORKSHOP_HOME
}

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { log_err "Required command not found: $c"; exit 1; }
  done
}

require_kerberos_ticket() {
  if ! klist -s 2>/dev/null; then
    log_err "No valid Kerberos ticket. Run: kinit <your_user>"
    exit 1
  fi
}

# Optional flags for bootstrap/setup/verify/teardown (see workshop_admin_usage).
parse_workshop_admin_args() {
  CDP_WORKSHOP_SKIP_ADMIN_KINIT="${CDP_WORKSHOP_SKIP_ADMIN_KINIT:-0}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-kinit|--use-existing-ticket)
        CDP_WORKSHOP_SKIP_ADMIN_KINIT=1
        shift
        ;;
      --root)
        export WORKSHOP_ROOT="${2:?--root needs an HDFS path}"
        shift 2
        ;;
      -h|--help)
        workshop_admin_usage
        exit 0
        ;;
      *)
        log_err "Unknown argument: $1 (try --help)"
        exit 1
        ;;
    esac
  done
  export CDP_WORKSHOP_SKIP_ADMIN_KINIT
}

workshop_admin_usage() {
  cat <<EOF
Usage: $(basename "${0}") [--skip-kinit] [--root HDFS_DIR]

  --skip-kinit, --use-existing-ticket
    Use your current Kerberos ticket instead of kinit via the HDFS NameNode keytab.

  --root HDFS_DIR
    Workshop location on HDFS (default: WORKSHOP_ROOT from the environment or config.env).

  Environment: CDP_WORKSHOP_SKIP_ADMIN_KINIT=1 has the same effect as --skip-kinit.
EOF
}

# Admin bootstrap/setup: ticket as hdfs superuser (NameNode keytab on edge node).
require_admin_hdfs_kinit() {
  require_cmd kinit klist
  if [[ "${CDP_WORKSHOP_SKIP_ADMIN_KINIT:-0}" == "1" ]]; then
    if ! klist -s 2>/dev/null; then
      log_err "No valid Kerberos ticket. Run kinit first, or omit --skip-kinit."
      exit 1
    fi
    local principal
    principal="$(klist 2>/dev/null | awk '/Default principal/ {print $3; exit}')"
    log_info "Using existing Kerberos ticket${principal:+ (${principal})}"
    return 0
  fi
  # shellcheck source=admin_auth.sh
  source "${_ws_script_dir}/admin_auth.sh"
  admin_kinit_hdfs
}

require_hdfs() {
  require_cmd hdfs
  hdfs dfs -ls "${WORKSHOP_ROOT}" >/dev/null 2>&1 || {
    log_err "Cannot list ${WORKSHOP_ROOT}. Check kinit and HDFS access."
    exit 1
  }
}
