# Module 04 — Basics: Hive

SQL over the grid monitoring pilot data: put external and managed Hive tables on the smart-meter, market, and weather files you met in modules 02 and 03, look at how the files are stored on HDFS, and learn why external tables cannot be changed row by row.

**Estimated time:** ~100 minutes (core ~85 min + stretch). The lab splits cleanly into two blocks — sections 0–5 (external tables, partitions, formats, failed updates) and sections 6–10 (managed tables, SQL basics, a first join, statistics) — if you prefer two shorter sessions. Safe re-runnable loads for external tables (overwrite, rewrite, merge) and Iceberg tables live in the [lakehouse module](../07-lakehouse-iceberg/README.md).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Module [02-basics-hdfs](../02-basics-hdfs/README.md) complete — you use `hdfs dfs` throughout
- Module [03-basics-yarn](../03-basics-yarn/README.md) complete — Hive queries run as Tez applications
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`) and the HiveServer2 JDBC URL from your handout

## Learning goals

After this module you can:

- Create external tables on CSV files you copied to HDFS, and explain why the table is "just a folder"
- Add partitions to an external table with `ADD PARTITION` and `MSCK REPAIR TABLE`
- Store the same data as text, ORC, and Parquet, and inspect the files on HDFS to see columnar storage
- Explain why `UPDATE` and `DELETE` fail on external tables, and why `INSERT INTO` is not safe to retry (`INSERT OVERWRITE` is)
- Create managed (ACID) tables and use `UPDATE`, `DELETE`, and `MERGE`
- Write everyday Hive SQL: filter, aggregate, `CASE`, `NULL` handling, views, and a basic join
- Collect table and column statistics with `ANALYZE TABLE` and explain what the optimizer uses them for

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Hive architecture (HiveServer2, Metastore, Tez); schema on read; external vs managed; row vs column formats |
| Core lab | [lab_basics_hive.md](lab/lab_basics_hive.md) sections 0–10 |
| Stretch | [lab_basics_hive.md](lab/lab_basics_hive.md) stretch tasks |
| Self-check | `./04-basics-hive/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, CDP pitfalls, Ranger prerequisites  
- [trainer/demos.md](trainer/demos.md) — managed table files, `DROP` behavior, small files (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./04-basics-hive/setup/setup.sh
./04-basics-hive/setup/verify.sh
```

(Ranger policies for Hive are a separate step — see the [ranger README](../00-setup/admin/ranger/README.md).)

Window functions, complex joins, complex types, and WKT geo data are in [10-advanced-hive](../10-advanced-hive/README.md).

## Next module

[05-basics-impala](../05-basics-impala/README.md)

---
*The generation of these labs was supported by AI.*
