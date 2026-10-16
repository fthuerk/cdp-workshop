#!/usr/bin/env bash
# Obtain a Kerberos ticket as the HDFS service user (admin bootstrap only).

set -euo pipefail

admin_kinit_hdfs() {
  export KRB5CCNAME="${KRB5CCNAME:-/tmp/krb5cc_cdp_workshop_admin}"
  local keytab principal
  keytab="$(find /run/cloudera-scm-agent/process -path '*-hdfs-NAMENODE/hdfs.keytab' -print -quit 2>/dev/null || true)"
  if [[ -z "${keytab}" || ! -f "${keytab}" ]]; then
    echo "HDFS NameNode keytab not found under /run/cloudera-scm-agent/process" >&2
    echo "Run this on an edge node with CM agent, or kinit manually as hdfs superuser." >&2
    exit 1
  fi
  principal="$(klist -kt "${keytab}" | awk 'NR>3 {print $4; exit}')"
  if [[ -z "${principal}" ]]; then
    echo "Could not read principal from ${keytab}" >&2
    exit 1
  fi
  kinit -kt "${keytab}" "${principal}"
  echo "Authenticated as ${principal}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  admin_kinit_hdfs
  klist
fi
