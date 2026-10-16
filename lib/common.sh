#!/usr/bin/env bash
# Shared helpers for cdp-workshop scripts.

set -euo pipefail

_ws_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ws_repo_root="$(cd "${_ws_script_dir}/.." && pwd)"

load_config() {
  local cfg="${CDP_WORKSHOP_CONFIG:-${_ws_repo_root}/config.env}"
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
  : "${WORKSHOP_ROOT:?WORKSHOP_ROOT must be set}"
  : "${WORKSHOP_LOCAL:?WORKSHOP_LOCAL must be set}"
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

require_hdfs() {
  require_cmd hdfs
  hdfs dfs -ls "${WORKSHOP_ROOT}" >/dev/null 2>&1 || {
    log_err "Cannot list ${WORKSHOP_ROOT}. Check kinit and HDFS access."
    exit 1
  }
}
