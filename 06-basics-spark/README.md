# Module 06 — Basics: Spark

Distributed transforms on the grid monitoring pilot data: read smart-meter and weather CSVs from HDFS with PySpark, cleanse and join time series on YARN, write curated Parquet to your personal folder, and register the result in the shared Hive Metastore.

**Estimated time:** ~90 minutes (core ~75 min + optional section and stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`)
- PySpark on the edge node (`pyspark`, `spark-submit` — or the names from your handout)

## Learning goals

After this module you can:

- Start a **SparkSession** on YARN and relate driver, executors, and the YARN application
- Read CSV with and without an explicit schema; use transformations and actions on workshop meter and weather data
- **Cleanse** rows (quality flags, timestamps, nulls) and **aggregate** with the DataFrame API and Spark SQL
- **Join** meter readings with operator weather and optional market prices on aligned timestamps
- Write **Parquet** partitioned output to HDFS and inspect files with `hdfs dfs`
- Run the same pipeline with **`spark-submit`** in cluster mode and read driver output from YARN logs
- Register Parquet as an **external** table in `<user>` and recognize common Spark failure signals on YARN

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Spark vs MapReduce/Tez; lazy evaluation; batch vs interactive; place in the landing → curated pipeline |
| Core lab | [lab_basics_spark.md](lab/lab_basics_spark.md) sections 0–7 |
| Optional | [lab_basics_spark.md](lab/lab_basics_spark.md) section 8 (failure signals) |
| Stretch | [lab_basics_spark.md](lab/lab_basics_spark.md) stretch |
| Self-check | `./06-basics-spark/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls  
- [trainer/demos.md](trainer/demos.md) — Spark History Server, deliberate resource failures (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./06-basics-spark/setup/setup.sh
./06-basics-spark/setup/verify.sh
```

(Ranger: same Hive `{USER}` pattern as module 04; HDFS write under `/user/<participant>` and optional `${WORKSHOP_ROOT}/06-spark/work` — see [ranger README](../00-setup/admin/ranger/README.md).)

## Next module

[07-lakehouse-iceberg](../07-lakehouse-iceberg/README.md)

---
*The generation of these labs was supported by AI.*
