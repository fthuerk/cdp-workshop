# Module 07 — Lakehouse: Iceberg

The follow-up to the Hive module: what **Apache Iceberg** adds to a table. One external source table and one Iceberg table; all SQL runs in the **Hue Impala editor**. You look at the files behind the Iceberg table on HDFS, change single rows with `UPDATE`, `DELETE`, and `MERGE`, travel back in time, undo a mistake, and expire old snapshots.

**Estimated time:** ~60 minutes (core ~50 min + stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes); the lab creates its own database and source tables from the shared sample data
- Recommended background: [04-basics-hive](../04-basics-hive/README.md) (external vs managed tables; the failed `UPDATE` on an external table) and [05-basics-impala](../05-basics-impala/README.md)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`) for the `hdfs` commands, Hue login, and the `impala-shell` options from your handout (only for `check.sh`)
- Cloudera Runtime 7.3.2 or later (Impala `UPDATE` and `MERGE` need 7.3.1.500 or later)

## Learning goals

After this module you can:

- Create an Iceberg table in Impala and explain the `data/` and `metadata/` folders, manifests, and snapshots you see on HDFS
- Run `UPDATE`, `DELETE`, and `MERGE` on the table, and explain merge-on-read (delete files)
- List snapshots, read old states with time travel, and compare two snapshots with a join
- Explain snapshot isolation: readers see one consistent snapshot, writers commit atomically
- Roll back a wrong change and expire old snapshots, and see what happens to the files

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Why external tables cannot be changed row by row; what a table format adds (metadata layer, snapshots, atomic commit); one table, many possible engines |
| Core lab | [lab_lakehouse_iceberg.md](lab/lab_lakehouse_iceberg.md) sections 0–5 |
| Stretch | Repartitioning (partition evolution), compaction |
| Self-check | `./07-lakehouse-iceberg/lab/check.sh` (before the stretch) |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, CDP 7.3.2 pitfalls, Ranger prerequisites  
- [trainer/tutorial-iceberg.md](trainer/tutorial-iceberg.md) — live demos (isolation, concurrent writers, compaction, Ranger audit, drop), more Iceberg functions, and Impala vs Hive vs Spark on CDP 7.3.2 (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./07-lakehouse-iceberg/setup/setup.sh
./07-lakehouse-iceberg/setup/verify.sh
```

The module has no data of its own: participants create their database and Iceberg tables in the default external warehouse folder of their `<user>` database. What is needed is Ranger: Hive/Impala policies on `{USER}`, HDFS `rwx` on `/warehouse/tablespace/external/hive/{USER}.db`, plus the **storage handler policy for Iceberg** — see the [ranger README](../00-setup/admin/ranger/README.md).

## Next module

[10-advanced-hive](../README.md) (planned — see root README): window functions, ranking, and performance tuning on the same tables.

---
*The generation of these labs was supported by AI.*
