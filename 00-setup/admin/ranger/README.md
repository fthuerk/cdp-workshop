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

1. **Databases and tables:** allow `create`, `select`, `update`, `drop`, `alter`, `index`, `lock` on database `{USER}` (Ranger macro: each user gets access to the database named like the user), table `*`, column `*` for the workshop users (or group). Participants create `<user>` themselves.  
2. **HDFS for participants:** the lab uses the **default external location** only (no `LOCATION` clauses). Participants copy files into `/warehouse/tablespace/external/hive/<user>.db/<table>`, so allow `read`/`write`/`execute` for the workshop users on `/warehouse/tablespace/external/hive/{USER}.db` (recursive; `{USER}` macro again), and read on `${WORKSHOP_ROOT}/data` and `${WORKSHOP_ROOT}/04-hive/landing`. Hive itself writes there as the `hive` user, which already has access to the warehouse.  
3. **No URL policy needed** for module 04, because tables never set a custom location (this comes in a later lab).

## Hive policies for module 06 Spark (manual, Ranger UI)

Same **`{USER}` database/table** pattern as module 04. Participants write Parquet files under **`/user/<participant>/`** (their HDFS home; default home ownership is enough) and save the final table with `saveAsTable` at the **default location** — no `LOCATION` clause, so no URL policy. Spark and Hive need the same access to `/warehouse/tablespace/external/hive/{USER}.db` as in module 04.

## Hive and HDFS policies for module 09 Livy (manual, Ranger UI)

Livy runs Spark as the participant (impersonation), so the policies of module 06 apply unchanged: Hive `{USER}` database/table privileges, HDFS write on `/user/<participant>` (default home ownership) and on `/warehouse/tablespace/external/hive/{USER}.db`, read on `${WORKSHOP_ROOT}/data` and `${WORKSHOP_ROOT}/09-livy/assets`. The table is created without `LOCATION`, so no URL policy is needed. Outside Ranger, the workshop users must be allowed to use the Livy service in the Knox topology, and the Livy service user needs proxy-user rights for them (see the [module 09 trainer notes](../../../09-basics-livy/trainer/notes.md)).

## Hive / Impala policies for module 05 (manual, Ranger UI)

Same pattern as module 04: `{USER}` database/table privileges and read/write on the default external location `/warehouse/tablespace/external/hive/{USER}.db`. The lab sets no `LOCATION`, so no URL policy is needed. If Impala has a separate Ranger service, grant `SELECT` (and `CREATE` on `{USER}`) for workshop users. Read on `${WORKSHOP_ROOT}/05-impala/scaled` is prepared by `05-basics-impala/setup/setup.sh`.

## Hive, Impala and Spark policies for module 14 Data types (manual, Ranger UI)

Same `{USER}` database/table privileges and read/write on `/warehouse/tablespace/external/hive/{USER}.db` as in modules 05 and 06 (the lab sets no `LOCATION`, so no URL policy). Read on `${WORKSHOP_ROOT}/14-datatypes/edge` is prepared by `14-basics-datatypes/setup/setup.sh`. Views are created in the personal database, so participants need `create` there.

## Hive policies for module I2 Atlas (manual, Ranger UI)

Only the `create`/`select`/`insert` privileges on personal databases from module 04. The lab creates managed tables at the default location (no `LOCATION`, no files copied), so no URL or HDFS policy is needed. Atlas itself needs the Hive hook enabled and, for classifications and glossary, Atlas permissions (see the module trainer notes).

## Iceberg policies for module 07 (manual, Ranger UI)

Module 07 uses the module 04 policies (Hive on `{USER}`, HDFS `rwx` on `/warehouse/tablespace/external/hive/{USER}.db`) and one more. Not validated:

1. **Storage handler policy:** in the Hadoop SQL service edit the policy "all - storage-type, storage-url": set storage-type to `iceberg`, storage-url to `*` (include), and grant *RW Storage* to the workshop users (or `public`). Without it, `CREATE TABLE … STORED BY ICEBERG` fails. The exact policy name depends on your Ranger version; see the Cloudera Iceberg documentation for 7.3.2.  
2. **Table policy:** the Hive policy of module 04 (create, select, update, drop, alter on `{USER}`) also covers the Iceberg tables.  
3. **Spark:** Spark reads and writes the Iceberg files as the participant, so the HDFS policy on the external warehouse folder is what counts. Impala runs as the `impala` user.  
4. **Compaction (stretch task):** the user who compacts needs `ALL` on the table.

## Kafka policies for module 15 (manual, Ranger UI)

In the **Kafka** service (often `cm_kafka`); not validated. Kerberos user names must reach Ranger as plain short names: check the Kafka setting `sasl.kerberos.principal.to.local.rules` (default rule turns `user@REALM` into `user`). Policies for the workshop users (or the `workshop` group):

1. **Personal topic:** topic `{USER}` (exactly the user name, no pattern), permissions `create`, `describe`, `publish`, `consume`, `delete`, `configure` (alter configs), `alter` (add partitions). Every participant has exactly one topic; creating any other name is refused.
2. **Consumer group:** consumergroup `{USER}` (exactly the user name), permissions `consume`, `describe`, `delete`. All consumers of the lab, also on the shared topic, run with `--group <user>`, so no pattern for random console-consumer groups is needed.
3. **Shared topic:** topic `grid-measurements`, permissions `describe` and `consume` only. No `publish` for participants (section 6 of the lab depends on the refusal). `setup.sh` runs as a Kafka admin with all permissions.
4. **Cluster:** no permission needed for the lab (`describe` on the cluster is only needed to list consumer groups of others).

If the `{USER}` macro is not accepted for the Kafka resources in your Ranger version, add one policy per user (topic and group named like the user), or fall back to wildcards (then users can also touch the topics of others). Hive and HDFS policies are not needed for this module; the lab only reads `${WORKSHOP_ROOT}/data/grid_measurements` (module 00 setup).

## REST apply (experimental)

```bash
# Requires RANGER_URL, RANGER_USER, RANGER_PASSWORD, RANGER_HDFS_SERVICE in config.env
./00-setup/admin/ranger/apply_policies.sh
```

Adjust service name and resource paths to match your CM/Ranger deployment before use.

---
*The generation of these labs was supported by AI.*
