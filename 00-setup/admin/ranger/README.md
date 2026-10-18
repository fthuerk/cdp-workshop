# Ranger HDFS policies (optional)

These JSON files are **templates** for Apache Ranger HDFS policies supporting module **01** demos (read workshop data, deny `secret`, write `public` and `quota_reached`).

**Status:** not validated on your cluster. Test in a non-production environment first.

## Manual fallback (Ranger UI)

1. **Workshop read:** allow `read` + `execute` on `${WORKSHOP_ROOT}` and `${WORKSHOP_ROOT}/data/*` for workshop users (or `public` group); exclude `${WORKSHOP_ROOT}/01-hdfs/secret`.
2. **Secret deny:** explicit deny `read` on `${WORKSHOP_ROOT}/01-hdfs/secret/*` for all users except admins.
3. **Public write:** allow `write` on `${WORKSHOP_ROOT}/01-hdfs/public` for workshop users.
4. **Quota lab:** allow `write` on `${WORKSHOP_ROOT}/01-hdfs/quota_reached` (quota enforced by HDFS, not Ranger).

Module setup also sets POSIX permissions so labs work if Ranger is delayed.

## Hive policies for module 03 (manual, Ranger UI)

The JSON templates only cover HDFS. The Hive lab needs these policies in the **Hive** service (adjust names to your deployment; not validated):

1. **Databases and tables:** allow `create`, `select`, `update`, `drop`, `alter`, `index`, `lock` on database `ws_*`, table `*`, column `*` for the workshop users (or group). Participants create `ws_<user>` themselves.  
2. **URLs:** allow `read` and `write` on the URL `${WORKSHOP_ROOT}/*` (the Hive URL resource is the HDFS path used in `LOCATION`) for the workshop users.  
3. **HDFS for the `hive` user:** HiveServer2 normally accesses HDFS as `hive`. Allow `read`/`execute` on `${WORKSHOP_ROOT}/data` and `read`/`write`/`execute` on `${WORKSHOP_ROOT}/03-hive/work`. Module setup also adds a POSIX ACL for `hive` on the work folder.

## REST apply (experimental)

```bash
# Requires RANGER_URL, RANGER_USER, RANGER_PASSWORD, RANGER_HDFS_SERVICE in config.env
./00-setup/admin/ranger/apply_policies.sh
```

Adjust service name and resource paths to match your CM/Ranger deployment before use.
