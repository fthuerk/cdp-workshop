# Module 07 — Lakehouse: Iceberg

The follow-up to the Hive module: how to change, delete, and merge data **safely** — first the manual way on external tables (partition overwrite, rewrite, merge by rewriting), then with Apache Iceberg tables. All SQL runs in the **Hue Impala editor**; you look at the files behind an Iceberg table on HDFS, travel back in time, undo a mistake, and finish with joins on the same smart-meter data.

**Estimated time:** ~120 minutes (core ~100 min + stretch). The lab splits cleanly into two blocks — sections 0–3 (the old way, Iceberg tables, row-level changes) and sections 4–8 (history, time travel, isolation, joins, rollback) — if you prefer two shorter sessions.

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes); the lab creates its own database and source tables from the shared sample data
- Recommended background: [04-basics-hive](../04-basics-hive/README.md) (external vs managed tables, partitions) and [06-basics-impala](../06-basics-impala/README.md)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`) for the `hdfs` commands, Hue login, and the `impala-shell` options from your handout (only for `check.sh`)
- Cloudera Runtime 7.3.2 or later (Impala `UPDATE` and `MERGE` need 7.3.1.500 or later)

## Learning goals

After this module you can:

- Apply the idempotent patterns for external tables (`INSERT OVERWRITE`, rewrite a partition, drop a partition and its files, merge by rewriting) — and name their limits
- Create an Iceberg table in Impala and explain the `data/` and `metadata/` folders, manifests, and snapshots you see on HDFS
- Run `UPDATE`, `DELETE`, and `MERGE` on the table, and explain merge-on-read (delete files)
- List snapshots and read old states with time travel
- Explain snapshot isolation: readers see one consistent snapshot, writers commit atomically
- Roll back a wrong change and expire old snapshots, and see what happens to the files
- Write semi, anti, full outer, and range joins, and compare two snapshots with a join

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Why external tables cannot be changed row by row; what a table format adds (metadata layer, snapshots, atomic commit); one table, a metadata layer, many possible engines |
| Core lab | [lab_lakehouse_iceberg.md](lab/lab_lakehouse_iceberg.md) sections 0–8 |
| Stretch | [lab_lakehouse_iceberg.md](lab/lab_lakehouse_iceberg.md) stretch tasks (migrate in place, partition evolution, compaction, drop) |
| Self-check | `./07-lakehouse-iceberg/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, CDP 7.3.2 pitfalls, Ranger prerequisites  
- [trainer/demos.md](trainer/demos.md) — long-running reader, concurrent writers, files after compaction (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./07-lakehouse-iceberg/setup/setup.sh
./07-lakehouse-iceberg/setup/verify.sh
```

The module has no data of its own: participants create their database and Iceberg tables in the default external warehouse folder of their `ws_<user>` database. What is needed is Ranger: Hive/Impala policies on `ws_*`, HDFS `rwx` on `/warehouse/tablespace/external/hive/ws_*`, plus the **storage handler policy for Iceberg** — see the [ranger README](../00-setup/admin/ranger/README.md).

## Next module

[10-advanced-hive](../README.md) (planned — see root README): window functions, ranking, and performance tuning on the same tables.
