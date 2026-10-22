# Trainer notes — Module 05 Impala

**Dry-run status:** run once with a participant account before the session; Impala error text for UPDATE/DELETE varies by CDP version.

## Suggested timing (~45 min)

| Minutes | Activity |
|---------|----------|
| 0–8 | Concept: shared Metastore, Impala MPP vs Hive-on-Tez, read vs transform/write |
| 8–15 | Sections 0–1: shell, database, external table, row count 15,000 |
| 15–22 | Section 2: aggregations |
| 22–32 | Section 3: timed Impala vs Hive; show Tez app on YARN |
| 32–40 | Section 4: UPDATE/DELETE errors (Impala then Hive) — emphasize **expected** failures |
| 40–45 | Section 5: extra file + `INVALIDATE METADATA`; `check.sh` |

If time is tight, shorten section 5 to a verbal demo (you append a file and invalidate on the projector).

## Check-question answers

1. **Metastore (0):** Database metadata lives in the Metastore (RDBMS), not in HDFS.  
2. **Who owns bytes (1):** HDFS holds files; the Metastore holds the table pointer and schema.  
3. **ORC/Parquet (2):** Exploration can start on CSV; production curated layers use columnar formats for less I/O — module 04 goes deep on that pattern.  
4. **Hive vs Impala (3):** Hive for ETL (`INSERT OVERWRITE`, ACID merges, heavy transforms, UDF chains); Impala for interactive BI and dashboards on stable tables.  
5. **Immutable files (4):** HDFS files are append/replace at file granularity; row edits need transactional tables, Kudu, or rewrite-partition patterns.  
6. **INVALIDATE (5):** Pipelines should document when metadata refresh runs (after load completes); ad-hoc users refresh if they see stale counts.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| `IMPALA_OPTS` wrong | Put the exact `impala-shell -i …` line on the handout; test from edge node |
| No speed difference | Cluster idle + small data — focus on Tez app vs none; scaled file is 15k rows |
| Hive faster once | Second Hive query reuses Tez session — tell room to compare **first** Hive run after `kinit` or use a fresh Beeline JVM |
| Copy lands in wrong folder | No `LOCATION` is used: the CSV must go to `${IMPALA_EXT}/impala_meter` (default external folder), then `REFRESH impala_meter` |
| Section 4 scares people | Say loudly: **red errors are the learning goal** |
| Ranger | Same `ws_*` policies and default external warehouse access as Hive; no URL policy and no extra HDFS path |

## Admin

[setup/setup.sh](../setup/setup.sh) builds `meter-15k.csv` under `${WORKSHOP_ROOT}/05-impala/scaled/`.

## After module

Module 06 Spark reads the same `${WORKSHOP_ROOT}/data` paths; module 12 (advanced Impala) adds KPI-style analytics on curated tables.
