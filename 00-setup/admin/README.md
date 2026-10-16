# Module 00 — Admin bootstrap

Run on an **edge node** as a user that can authenticate as HDFS superuser (see `lib/admin_auth.sh`).

## Prerequisites

- `config.env` copied from `config.env.example` with correct `WORKSHOP_ROOT` and `WORKSHOP_LOCAL`
- Repo present at `WORKSHOP_LOCAL` (git clone or release zip)
- Optional: `participants.txt` (one Unix username per line) for pre-created `/user/<name>`

## Order of operations

1. Authenticate:
   ```bash
   source lib/admin_auth.sh   # or: bash lib/admin_auth.sh
   ```
2. Bootstrap shared data:
   ```bash
   ./00-setup/admin/bootstrap.sh
   ./00-setup/admin/verify.sh
   ```
3. Module **01** HDFS lab paths (secret, quota, big file):
   ```bash
   ./01-basics-hdfs/setup/setup.sh
   ./01-basics-hdfs/setup/verify.sh
   ```
4. **Optional — Ranger** (test in dev first; manual UI fallback in `ranger/README.md`):
   ```bash
   ./00-setup/admin/ranger/apply_policies.sh
   ```

## Reset between cohorts

```bash
./01-basics-hdfs/setup/teardown.sh
./00-setup/admin/teardown.sh
```

Scripts are idempotent where possible; teardown removes workshop-created paths only under `${WORKSHOP_ROOT}`.

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `keytab not found` | Run on CM-managed edge node or `kinit` as hdfs manually |
| `put: Permission denied` | Confirm superuser ticket; check encryption zones |
| Samples missing | Verify `WORKSHOP_LOCAL/data/samples/*.csv` exists |
