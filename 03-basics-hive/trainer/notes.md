# Trainer notes — Module 03 Hive

**Dry-run status:** the lab SQL has not been run end to end on the target cluster yet. Do one full run with a normal participant account before the session, fix anything that differs on your CDP version, and note it in [Pitfalls](#pitfalls).

## Suggested timing (~120 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: HiveServer2 → Metastore → Tez → HDFS; schema on read; external vs managed (whiteboard) |
| 10–15 | Section 0: Beeline, `--hivevar`, own database |
| 15–27 | Sections 1–2: external CSV table, NULL on wrong types, `DROP` |
| 27–40 | Section 3: `ADD PARTITION`, `MSCK REPAIR`, pruning with `EXPLAIN DEPENDENCY` / `EXTENDED` |
| 40–53 | Section 4: formats; **walk the room** while they run `orcfiledump`, then explain stripes/streams on screen |
| 53–60 | Section 5: UPDATE/DELETE error, `INSERT INTO` duplicate |
| 60–77 | Section 6: idempotent patterns (the most important 17 minutes of the module) |
| 77–80 | Short break |
| 80–91 | Sections 7–8: managed table, UPDATE/DELETE/MERGE; live demo [demos.md](demos.md) section 1 |
| 91–103 | Section 9: SQL basics |
| 103–114 | Section 10: joins |
| 114–120 | Section 11 relate; `check.sh` |

If you run short, shorten sections 9–10 (they are the most "self-service") and keep 3–6 intact. If you split into two sessions, break after section 6 and start the second block with the section 7 concept.

## Check-question answers

1. **Metastore vs HDFS (0):** The Metastore knows the table (name, columns, location, format); the data is files in HDFS. Drop the table in a metastore and the files may remain (external).  
2. **New file appears (1):** The table is the folder. Anything landed in it is read on the next query. Good for simple ingestion, risky when half-written files or other formats land in the same folder — land in a staging folder, move atomically.  
3. **INT vs 1.5 (2):** Hive returns `NULL`, no error. Notice it with a `COUNT(*)` vs `COUNT(col)` comparison, `WHERE col IS NULL` counts, or a quality gate that compares row counts and null rates between runs.  
4. **Missing `dt=` partition (3):** The Metastore does not know the new folder. Fix with `ALTER TABLE … ADD PARTITION` (explicit, cheap, best in pipelines) or `MSCK REPAIR TABLE` (scans all folders; fine for small tables, slow for thousands of partitions). Mention background discovery (`discover.partitions`) as the managed alternative.  
   **Pruning (3, first question):** Only the query filtering on the partition column (`station_id = …`) reads a subset; with two years of daily data it must be partitioned by date, and the query must filter on that column. A filter on a normal column (`quality_flag`) reads every partition — Hive needs the partition column in the `WHERE` clause (or a join/predicate Hive can resolve statically). Stress that pruning needs a literal or expression on the partition column; a filter on a derived value (e.g. `ts_utc` when partitioned by `dt`) does not prune.  
5. **ORC columns (4):** `event_code` and `comm_status` have very few distinct values, so dictionary + run-length encoding shrinks them to almost nothing; `current_a` is a high-cardinality double, so it stays large. Columnar storage compresses each column on its own. Analysts reading a few columns read only those streams. Keep CSV only for landing (exchange format, human-readable, what source systems deliver).  
6. **Why UPDATE fails (5):** HDFS files are immutable (append only, no in-place edit) and an external table has no transaction metadata, so Hive has no way to track row versions. After a retry with `INSERT INTO` the table contains the data twice — silent duplicates.  
7. **Why OVERWRITE is safe (6):** The result depends only on the source, not on what was there. A dynamic partition overwrite only replaces partitions that appear in the `SELECT`; a station that is in the table but not in the source keeps its **stale** partition. Fix: overwrite explicit partitions, or drop partitions that should disappear.  
8. **Owner of raw vs curated (7):** Raw landing data: external — files are owned by the ingestion process, other engines (Spark, Impala) read them, and dropping a table must not delete source data. Curated tables only Hive writes: managed/ACID — Hive controls layout, updates, compaction, and cleanup; nobody should touch the files directly.  
9. **Why deltas (8):** Immutable files; Hive writes `delta_` (inserts/new versions) and `delete_delta_` folders and merges them at read time. Without compaction every read has to merge more and more small files — read performance degrades and the NameNode holds many small files.  
10. **`NULL` vs empty (9):** `IS NULL` returns 0 because delimited text yields empty **strings**; `= ''` returns the real number. A rule written with `IS NULL` reports zero problems. The view uses `NULLIF` to normalize.  
11. **Doubled rows (10):** Each timestamp exists twice in the weather table (two stations) — the join key is not unique on one side. Check key uniqueness (`GROUP BY key HAVING COUNT(*) > 1`) and compare row counts before and after the join.  
12. **EXPLAIN vs YARN (11):** `Map 1` / `Reducer 2` are Tez vertices (tasks in containers). The ApplicationMaster is the Tez AM of the HiveServer2 session — not visible as a vertex. Containers can be reused between queries of the same session, which is why the Tez application was already running.

## Talking points

- **Use case:** the files are the same CSVs from modules 01–02; `landisgyr_csv`, `stations`, `market_prices`, `weather_operator` are the "staging" layer from [concept.md](../../docs/concept.md). Everything after landing/staging becomes ORC/Parquet.  
- **Idempotency** is the thread through sections 5, 6, and 8: say "can I run this twice?" after every statement, and bring it back in the Spark and Oozie modules.  
- **Partitioning:** the lab partitions by `station_id` because the sample files cover one day. In production the partition is almost always a date (`dt=2026-01-15`) — the mechanics are identical. Warn against over-partitioning (high-cardinality keys, many tiny partitions).  
- **Timestamps:** the CSV has `2026-01-15T08:00:00Z`, which Hive's `TIMESTAMP` cast does not parse directly. Section 9's view shows the cleanup (`REPLACE`/`SUBSTR`/`CAST`). Hive timestamps carry no time zone — all pilot data is UTC.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| HiveServer2 runs queries as `hive` (impersonation off, the CDP default) and cannot write to participant folders | `setup.sh` creates `${WORKSHOP_ROOT}/03-hive/work` with a default ACL for `hive`. If ACLs are disabled, use a Ranger HDFS policy for `hive` on that path |
| `CREATE DATABASE` / `CREATE TABLE … LOCATION` denied | Ranger Hive policies needed — see [ranger README](../../00-setup/admin/ranger/README.md): create on `ws_*`, all on `ws_*` tables, URL access for `${WORKSHOP_ROOT}/*` |
| Managed table files not readable by participants | Intentional (owner `hive`). Lab handles both outcomes; show the files yourself in [demos.md](demos.md) |
| Background partition discovery makes `MSCK REPAIR` step look "automatic" | Lab sets `discover.partitions=false` on the partitioned table. If your version ignores the property, tell participants to run the query right after the copy |
| Strict managed tables: `CREATE TABLE … STORED AS TEXTFILE` silently becomes an external table (HMS translation) | Lab only creates managed ORC/ACID tables via CTAS. Mention it if somebody tries a managed text table |
| First query slow (Tez session start) | Run one query yourself before the room starts; warn participants once |
| 15+ participants run Section 4/6 inserts at the same time | Queue capacity: check `yarn queue -status` (module 02). Stagger by 1–2 min or use a workshop queue |
| `hive --orcfiledump` not on PATH, or noisy log output | Troubleshooting has the fallback; the sizes from `-du` are enough for the point |
| `parquet-tools` not installed | Lab uses `strings` on the footer; `parquet-tools meta` is only a stretch item |
| `INSERT OVERWRITE` from the same table partition | Works on non-ACID tables (Hive writes to a staging folder and swaps). If it fails on your version, use a temp table: `CREATE TABLE tmp AS SELECT …`, overwrite from it, drop it |
| `UPDATE` error text differs per version | The message always mentions that the table is not transactional |

## Ranger and permissions summary

Participants need (details for admins in the [ranger README](../../00-setup/admin/ranger/README.md)):

1. Create database and tables named `ws_<user>` / inside it (Hive policy on `ws_*`).  
2. Read access for `hive` on `${WORKSHOP_ROOT}/data` (POSIX default is enough) and read/write on `${WORKSHOP_ROOT}/03-hive/work`.  
3. Hive URL policy for `${WORKSHOP_ROOT}/*` so `LOCATION` clauses are accepted.  
4. Compaction needs no extra permission (it runs inside the Metastore).

## Admin

Run [setup/setup.sh](../setup/setup.sh) after bootstrap: it splits the Landis&Gyr sample into one folder per station under `${WORKSHOP_ROOT}/03-hive/landing/` and prepares the shared work area. Participant databases (`ws_<user>`) are **not** removed by [setup/teardown.sh](../setup/teardown.sh) — drop them as a Hive admin.

## After module

Preview module 04 (Spark): Spark reads the same Parquet/ORC files and external tables through the Metastore — the folders you built in `${HIVE_WORK}` are the input. Advanced Hive (module 10) builds on sections 3, 4, and 6: partition design, bucketing, window functions and ranking, and performance tuning.
