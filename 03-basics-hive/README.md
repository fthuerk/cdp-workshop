# Module 03 — Basics: Hive

SQL over the grid monitoring pilot data: put external and managed Hive tables on the smart-meter, market, and weather files you met in modules 01 and 02, look at how the files are stored on HDFS, and learn the patterns that make table loads safe to re-run.

**Estimated time:** ~120 minutes (core ~105 min + stretch). The lab splits cleanly into two blocks — sections 0–6 (external tables, partitions, formats, idempotent loads) and sections 7–11 (managed tables, SQL basics, joins) — if you prefer two shorter sessions.

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Module [01-basics-hdfs](../01-basics-hdfs/README.md) complete — you use `hdfs dfs` throughout
- Module [02-basics-yarn](../02-basics-yarn/README.md) complete — Hive queries run as Tez applications
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`) and the HiveServer2 JDBC URL from your handout

## Learning goals

After this module you can:

- Create external tables on CSV files you copied to HDFS, and explain why the table is "just a folder"
- Add partitions to an external table with `ADD PARTITION` and `MSCK REPAIR TABLE`
- Store the same data as text, ORC, and Parquet, and inspect the files on HDFS to see columnar storage
- Explain why `UPDATE` and `DELETE` fail on external tables, and use partition overwrite, rewrite, and drop as idempotent workarounds
- Create managed (ACID) tables and use `UPDATE`, `DELETE`, and `MERGE`
- Write everyday Hive SQL: filter, aggregate, `CASE`, `NULL` handling, views, CTEs, and joins
- Relate a Hive query to its Tez application on YARN

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Hive architecture (HiveServer2, Metastore, Tez); schema on read; external vs managed; row vs column formats |
| Core lab | [lab/lab.md](lab/lab.md) sections 0–11 |
| Stretch | [lab/lab.md](lab/lab.md) stretch tasks |
| Self-check | `./03-basics-hive/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, CDP pitfalls, Ranger prerequisites  
- [trainer/demos.md](trainer/demos.md) — managed table files, `DROP` behavior, small files (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./03-basics-hive/setup/setup.sh
./03-basics-hive/setup/verify.sh
```

(Ranger policies for Hive are a separate step — see the [ranger README](../00-setup/admin/ranger/README.md).)

## Next module

[04-basics-spark](../README.md) (planned — see root README)
