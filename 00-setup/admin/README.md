# Module 00 — Admin bootstrap

Run on a **CM-managed edge node** (scripts call `kinit` as `hdfs` via the NameNode keytab before HDFS commands).

## Prerequisites

- `config.env` copied from `config.env.example` with correct `WORKSHOP_ROOT` and `WORKSHOP_LOCAL`
- Repo present at `WORKSHOP_LOCAL` (git clone or release zip)
- Optional: `participants.txt` (one Unix username per line) for pre-created `/user/<name>`

## Order of operations

1. Bootstrap shared data:
   ```bash
   ./00-setup/admin/bootstrap.sh
   ./00-setup/admin/verify.sh
   ```
2. Module **01** HDFS lab paths (secret, quota, big file):
   ```bash
   ./01-basics-hdfs/setup/setup.sh
   ./01-basics-hdfs/setup/verify.sh
   ```
3. Module **03** Hive lab paths (landing folders per station, shared work area with `hive` ACL):
   ```bash
   ./03-basics-hive/setup/setup.sh
   ./03-basics-hive/setup/verify.sh
   ```
4. **Optional — Ranger** (test in dev first; manual UI fallback in `ranger/README.md`):
   ```bash
   ./00-setup/admin/ranger/apply_policies.sh
   ```

## Reset between cohorts

```bash
./03-basics-hive/setup/teardown.sh
./01-basics-hdfs/setup/teardown.sh
./00-setup/admin/teardown.sh
```

Scripts are idempotent where possible; teardown removes workshop-created paths only under `${WORKSHOP_ROOT}`.


## kinit with hdfs system user

```bash
export KRB5CCNAME="${KRB5CCNAME:-/tmp/krb5cc_cdp_workshop_admin}"
keytab="$(find /run/cloudera-scm-agent/process -path '*-hdfs-NAMENODE/hdfs.keytab' -print -quit)"
principal="$(klist -kt "${keytab}" | awk '/^[[:space:]]+[0-9]/ {print $NF}' | grep -m1 '^hdfs/')"
kinit -kt "${keytab}" "${principal}"
klist
```

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `keytab not found` | Run on CM-managed edge node or `kinit` as hdfs manually |
| `put: Permission denied` | Confirm superuser ticket; check encryption zones |
| Samples missing | Verify `WORKSHOP_LOCAL/data/samples/*.csv` exists |
