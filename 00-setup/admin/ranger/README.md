# Ranger HDFS policies (optional)

These JSON files are **templates** for Apache Ranger HDFS policies supporting module **02** demos (read workshop data, deny `secret`, write `public` and `quota_reached`).

**Status:** not validated on your cluster. Test in a non-production environment first.

## Manual fallback (Ranger UI)

1. **Workshop read:** allow `read` + `execute` on `${WORKSHOP_ROOT}` and `${WORKSHOP_ROOT}/data/*` for workshop users (or `public` group); exclude `${WORKSHOP_ROOT}/02-hdfs/secret`.
2. **Secret deny:** explicit deny `read` on `${WORKSHOP_ROOT}/02-hdfs/secret/*` for all users except admins.
3. **Public write:** allow `write` on `${WORKSHOP_ROOT}/02-hdfs/public` for workshop users.
4. **Quota lab:** allow `write` on `${WORKSHOP_ROOT}/02-hdfs/quota_reached` (quota enforced by HDFS, not Ranger).

Module setup also sets POSIX permissions so labs work if Ranger is delayed.

## Hive policies for module 04 (manual, Ranger UI)

The JSON templates only cover HDFS. The Hive lab needs these policies in the **Hive** service (adjust names to your deployment; not validated):

1. **Databases and tables:** allow `create`, `select`, `update`, `drop`, `alter`, `index`, `lock` on database `ws_*`, table `*`, column `*` for the workshop users (or group). Participants create `ws_<user>` themselves.  
2. **HDFS for participants:** the lab uses the **default external location** only (no `LOCATION` clauses). Participants copy files into `/warehouse/tablespace/external/hive/ws_<user>.db/<table>`, so allow `read`/`write`/`execute` for the workshop users on `/warehouse/tablespace/external/hive/ws_*` (recursive), and read on `${WORKSHOP_ROOT}/data` and `${WORKSHOP_ROOT}/04-hive/landing`. Hive itself writes there as the `hive` user, which already has access to the warehouse.  
3. **No URL policy needed** for module 04, because tables never set a custom location (this comes in a later lab).

## Hive policies for module 05 Spark (manual, Ranger UI)

Same **`ws_*` database/table** pattern as module 04. Participants write Parquet under **`/user/<participant>/`** (their HDFS home) and register an external table with `LOCATION` pointing there — grant workshop users **read/write/execute** on their own `/user/<name>` tree (or rely on default home ownership). Optional shared folder `${WORKSHOP_ROOT}/05-spark/work/*` only if you redirect lab tables there; default setup uses personal paths only.

## Hive / Impala policies for module 06 (manual, Ranger UI)

Same pattern as module 04: `ws_*` database/table privileges and URL access for `${WORKSHOP_ROOT}/06-impala/work/*`. If Impala has a separate Ranger service, grant `SELECT` (and `CREATE` on `ws_*`) for workshop users. HDFS ACL on `${WORKSHOP_ROOT}/06-impala/work` is prepared by `06-basics-impala/setup/setup.sh`.

## Iceberg policies for module 07 (manual, Ranger UI)

Module 07 uses the module 04 policies (Hive on `ws_*`, HDFS `rwx` on `/warehouse/tablespace/external/hive/ws_*`) and one more. Not validated:

1. **Storage handler policy:** in the Hadoop SQL service edit the policy "all - storage-type, storage-url": set storage-type to `iceberg`, storage-url to `*` (include), and grant *RW Storage* to the workshop users (or `public`). Without it, `CREATE TABLE … STORED BY ICEBERG` fails. The exact policy name depends on your Ranger version; see the Cloudera Iceberg documentation for 7.3.2.  
2. **Table policy:** the Hive policy of module 04 (create, select, update, drop, alter on `ws_*`) also covers the Iceberg tables.  
3. **Spark:** Spark reads and writes the Iceberg files as the participant, so the HDFS policy on the external warehouse folder is what counts. Impala runs as the `impala` user.  
4. **Compaction (stretch task):** the user who compacts needs `ALL` on the table.

## REST apply (experimental)

```bash
# Requires RANGER_URL, RANGER_USER, RANGER_PASSWORD, RANGER_HDFS_SERVICE in config.env
./00-setup/admin/ranger/apply_policies.sh
```

Adjust service name and resource paths to match your CM/Ranger deployment before use.
