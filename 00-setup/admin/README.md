# Module 00 — Admin bootstrap

Run on a **CM-managed edge node** (scripts call `kinit` as `hdfs` via the NameNode keytab before HDFS commands, unless you pass **`--skip-kinit`** after you have authenticated yourself).

## Prerequisites

- `config.env` copied from `config.env.example` with correct `WORKSHOP_ROOT` and `WORKSHOP_LOCAL`
- Repo present at `WORKSHOP_LOCAL` (git clone or release zip)
- Optional: `participants.txt` (one Unix username per line) for pre-created `/user/<name>`

## Order of operations

1. Bootstrap shared data:
   ```bash
   ./00-setup/admin/bootstrap.sh          # or: ./00-setup/admin/bootstrap.sh --skip-kinit
   ./00-setup/admin/verify.sh --skip-kinit
   ```
2. Module **02** HDFS lab paths (secret, quota, big file):
   ```bash
   ./02-basics-hdfs/setup/setup.sh
   ./02-basics-hdfs/setup/verify.sh
   ```
3. Module **04** Hive lab paths (landing folders per station; participants work in the default Hive warehouse, see the Ranger README):
   ```bash
   ./04-basics-hive/setup/setup.sh
   ./04-basics-hive/setup/verify.sh
   ```
4. Module **10** Advanced Hive: no folders to create; the script checks the sample data the lab copies from:
   ```bash
   ./10-advanced-hive/setup/setup.sh
   ./10-advanced-hive/setup/verify.sh
   ```
5. Module **07** Lakehouse (Iceberg): no folders to create; the script checks prerequisites and reminds you of the Ranger storage handler policy:
   ```bash
   ./07-lakehouse-iceberg/setup/setup.sh
   ./07-lakehouse-iceberg/setup/verify.sh
   ```
6. **Optional — Ranger** (test in dev first; manual UI fallback in `ranger/README.md`):
   ```bash
   ./00-setup/admin/ranger/apply_policies.sh
   ```

## Reset between cohorts

```bash
./04-basics-hive/setup/teardown.sh
./02-basics-hdfs/setup/teardown.sh
./00-setup/admin/teardown.sh
```

Scripts are idempotent where possible; teardown removes workshop-created paths only under `${WORKSHOP_ROOT}`.


## Kerberos for admin scripts

**Automatic (default):** bootstrap and module `setup.sh` / `verify.sh` / `teardown.sh` obtain an `hdfs` ticket from the NameNode keytab.

**Manual ticket:** if you already ran `kinit`, pass **`--skip-kinit`** (alias **`--use-existing-ticket`**) or set `CDP_WORKSHOP_SKIP_ADMIN_KINIT=1`:

```bash
kinit hdfs/…   # or your usual hdfs superuser flow
./04-basics-hive/setup/setup.sh --skip-kinit
```

```bash
export KRB5CCNAME="${KRB5CCNAME:-/tmp/krb5cc_cdp_workshop_admin}"
keytab="$(find /run/cloudera-scm-agent/process -path '*-hdfs-NAMENODE/hdfs.keytab' -print -quit)"
principal="$(klist -kt "${keytab}" | awk '/^[[:space:]]+[0-9]/ {print $NF}' | grep -m1 '^hdfs/')"
kinit -kt "${keytab}" "${principal}"
klist
./00-setup/admin/bootstrap.sh --skip-kinit
```

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `keytab not found` | Run on CM-managed edge node or `kinit` as hdfs manually |
| `put: Permission denied` | Confirm superuser ticket; check encryption zones |
| Samples missing | Verify `WORKSHOP_LOCAL/data/samples/*.csv` exists |
