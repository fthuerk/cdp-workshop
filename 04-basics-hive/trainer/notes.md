# Trainer notes — Module 04 Hive

**Dry-run status:** the lab SQL has not been run end to end on the target cluster yet. Do one full run with a normal participant account before the session, fix anything that differs on your CDP version, and note it in [Pitfalls](#pitfalls).

## Suggested timing (~100 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: HiveServer2 → Metastore → Tez → HDFS; schema on read; external vs managed (whiteboard) |
| 10–15 | Section 0: Beeline, `--hivevar`, own database |
| 15–27 | Sections 1–2: external CSV table, NULL on wrong types, `DROP` |
| 27–40 | Section 3: `ADD PARTITION`, `MSCK REPAIR`, pruning with `EXPLAIN DEPENDENCY` / `EXTENDED` |
| 40–53 | Section 4: formats; **walk the room** while they run `orcfiledump`, then explain stripes/streams on screen |
| 53–60 | Section 5: UPDATE/DELETE error, `INSERT INTO` duplicate, `INSERT OVERWRITE` |
| 60–63 | Short break |
| 63–76 | Sections 6–7: managed table, UPDATE/DELETE/MERGE; live demo [demos.md](demos.md) section 1 |
| 76–88 | Section 8: SQL basics |
| 88–93 | Section 9: one basic join |
| 93–100 | Section 10: statistics; `check.sh`; bridge to the lakehouse module |

If you run short, shorten section 8 (they are the most "self-service") and keep 3–7 intact. If you split into two sessions, break after section 5 and start the second block with the section 6 concept. The question "how do I change one row in an external table safely?" is the opening of the [lakehouse module](../../07-lakehouse-iceberg/trainer/notes.md): say so at the end of section 5.

## Check-question answers

1. **Metastore vs HDFS (0):** The Metastore knows the table (name, columns, location, format); the data is files in HDFS. Drop the table in a metastore and the files may remain (external).  
2. **New file appears (1):** The table is the folder. Anything landed in it is read on the next query. Good for simple ingestion, risky when half-written files or other formats land in the same folder — land in a staging folder, move atomically.  
3. **INT vs 1.5 and purge (2):**  Hive returns `NULL`, no error. Notice it with a `COUNT(*)` vs `COUNT(col)` comparison, `WHERE col IS NULL` counts, or a quality gate that compares row counts and null rates between runs.  **Purge:** useful for scratch/staging tables that a pipeline creates and drops itself; dangerous on tables over shared or source data, because `DROP TABLE` (or a script that drops and recreates tables) then deletes the files. Default for external tables stays: metadata only. Purge on `DROP PARTITION` behaves differently between versions — not covered in the lab.  
4. **Missing `dt=` partition (3):** The Metastore does not know the new folder. Fix with `ALTER TABLE … ADD PARTITION` (explicit, cheap, best in pipelines) or `MSCK REPAIR TABLE` (scans all folders; fine for small tables, slow for thousands of partitions). Mention background discovery (`discover.partitions`) as the managed alternative.  
   **Pruning (3, first question):** Only the query filtering on the partition column (`station_id = …`) reads a subset; with two years of daily data it must be partitioned by date, and the query must filter on that column. A filter on a normal column (`quality_flag`) reads every partition — Hive needs the partition column in the `WHERE` clause (or a join/predicate Hive can resolve statically). Stress that pruning needs a literal or expression on the partition column; a filter on a derived value (e.g. `ts_utc` when partitioned by `dt`) does not prune.  
5. **ORC columns and CTAS (4):** CTAS takes column names and types from the query; the participant chooses the table type (`EXTERNAL`), the file format (`STORED AS`), and — by default — the folder.  `event_code` and `comm_status` have very few distinct values, so dictionary + run-length encoding shrinks them to almost nothing; `current_a` is a high-cardinality double, so it stays large. Columnar storage compresses each column on its own. Analysts reading a few columns read only those streams. Keep CSV only for landing (exchange format, human-readable, what source systems deliver).  
6. **Why UPDATE fails (5):** HDFS files are immutable (append only, no in-place edit) and an external table has no transaction metadata, so Hive has no way to track row versions. After a retry with `INSERT INTO` the table contains the data twice — silent duplicates. `INSERT OVERWRITE` computes the result from the source only, so a retry gives the same table (the partition-level patterns and their traps are in the lakehouse module).  
7. **Owner of raw vs curated (6):** Raw landing data: external — files are owned by the ingestion process, other engines (Spark, Impala) read them, and dropping a table must not delete source data. Curated tables only Hive writes: managed/ACID — Hive controls layout, updates, compaction, and cleanup; nobody should touch the files directly.  
8. **Why deltas (7):** Immutable files; Hive writes `delta_` (inserts/new versions) and `delete_delta_` folders and merges them at read time. Without compaction every read has to merge more and more small files — read performance degrades and the NameNode holds many small files.  
9. **`NULL` vs empty (8):** `IS NULL` returns 0 because delimited text yields empty **strings**; `= ''` returns the real number. A rule written with `IS NULL` reports zero problems. The view uses `NULLIF` to normalize.  
10. **Missing station in the join (9):** With an inner join the third station simply disappears from the result — no error, no `NULL`. A report built on it looks complete. Notice it by comparing the row or station count before and after the join, or with a left join and a `NULL` check. Left/anti-joins and row-multiplying joins are in the advanced lab (module 10).  
11. **Stale statistics (10):** `numRows` still shows the old count, because nothing updates statistics for files copied into an external table folder. The optimizer plans with wrong sizes (wrong join strategy, too few reducers), and with accurate-looking statistics Hive can even answer `COUNT(*)` from the Metastore with the old number. Analyze after every load that changes a table a lot — in a pipeline, as the last step of the load; for partitioned tables per new partition.

## Talking points

- **Use case:** the files are the same CSVs from modules 02–03; `landisgyr_csv` and `stations` (and `market_prices`, `weather_operator` in the advanced lab) are the "staging" layer from [concept.md](../../docs/concept.md). Everything after landing/staging becomes ORC/Parquet.  
- **Idempotency** is the thread through sections 5 and 7: say "can I run this twice?" after every statement, and bring it back in the Spark and Oozie modules.  
- **Partitioning:** the lab partitions by `station_id` because the sample files cover one day. In production the partition is almost always a date (`dt=2026-01-15`) — the mechanics are identical. Warn against over-partitioning (high-cardinality keys, many tiny partitions).  
- **Timestamps:** the CSV has `2026-01-15T08:00:00Z`, which Hive's `TIMESTAMP` cast does not parse directly. Section 8's view shows the cleanup (`REPLACE`/`SUBSTR`/`CAST`). Hive timestamps carry no time zone — all pilot data is UTC.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| Participants cannot `hdfs dfs -cp` into `/warehouse/tablespace/external/hive/ws_<user>.db/<table>` (folders are created by Hive as `hive`) | Ranger HDFS policy: `read`/`write`/`execute` on `/warehouse/tablespace/external/hive/ws_*` for the workshop users. Test with a normal participant account before the session |
| `CREATE DATABASE` / `CREATE TABLE` denied | Ranger Hive policies needed — see [ranger README](../../00-setup/admin/ranger/README.md): create on `ws_*`, all on `ws_*` tables. No URL policy needed: the lab never sets a `LOCATION` |
| Warehouse path differs on your cluster | `DESCRIBE DATABASE EXTENDED` shows it; adjust `HIVE_EXT` in the lab intro (and `check.sh` reads `HIVE_EXT` if exported) |
| Managed table files not readable by participants | Intentional (owner `hive`). Lab handles both outcomes; show the files yourself in [demos.md](demos.md) |
| Background partition discovery makes `MSCK REPAIR` step look "automatic" | Lab sets `discover.partitions=false` on the partitioned table. If your version ignores the property, tell participants to run the query right after the copy |
| Strict managed tables: `CREATE TABLE … STORED AS TEXTFILE` silently becomes an external table (HMS translation) | Lab only creates managed ORC/ACID tables via CTAS. Mention it if somebody tries a managed text table |
| Hue variables | The lab SQL uses the single plain variable `${ws_user}`: Hive resolves them from `--hivevar` in Beeline, and Hue shows an input field for each placeholder. Hue's syntax `${name=default}` pre-fills a field — use it in a saved query if you want to prepare an editor tab for the room. Keep it to this one variable; the default external location is derived from the database name |
| First query slow (Tez session start) | Run one query yourself before the room starts; warn participants once |
| 15+ participants run section 4 inserts at the same time | Queue capacity: check `yarn queue -status` (module 03). Stagger by 1–2 min or use a workshop queue |
| `hive --orcfiledump` not on PATH, or noisy log output | Troubleshooting has the fallback; the sizes from `-du` are enough for the point |
| `parquet-tools` not installed | Lab uses `strings` on the footer; `parquet-tools meta` is only a stretch item |
| `INSERT OVERWRITE` from the same table partition | Works on non-ACID tables (Hive writes to a staging folder and swaps). If it fails on your version, use a temp table: `CREATE TABLE tmp AS SELECT …`, overwrite from it, drop it |
| CTAS for **external** tables (section 4) is rejected on older Hive versions | Troubleshooting has the create-plus-insert fallback. Plain `CREATE TABLE … AS SELECT` without `EXTERNAL` would create a managed ACID table in CDP — useful contrast for section 6: same CTAS, different table type |
| `UPDATE` error text differs per version | The message always mentions that the table is not transactional |

## Ranger and permissions summary

Participants need (details for admins in the [ranger README](../../00-setup/admin/ranger/README.md)):

1. Create database and tables named `ws_<user>` / inside it (Hive policy on `ws_*`).  
2. Read/write/execute on `/warehouse/tablespace/external/hive/ws_*` (HDFS policy) so they can copy, list, and delete files in their table folders; read on `${WORKSHOP_ROOT}/data` and `${WORKSHOP_ROOT}/04-hive/landing`. The lakehouse module needs nothing new here: Iceberg tables live in the same default external folders.  
3. No Hive URL policy: custom `LOCATION` clauses are left for a later lab.  
4. Compaction needs no extra permission (it runs inside the Metastore).

## Admin

Run [setup/setup.sh](../setup/setup.sh) after bootstrap: it splits the Landis&Gyr sample into one folder per station under `${WORKSHOP_ROOT}/04-hive/landing/` (nothing else; participant data lives in the default Hive warehouse). Participant databases (`ws_<user>`) and their external table folders are **not** removed by [setup/teardown.sh](../setup/teardown.sh) — drop the databases as a Hive admin and delete leftover folders under `/warehouse/tablespace/external/hive/ws_<user>.db`.

## After module

Preview module 05 (Impala) and module 06 (Spark): Impala and Spark read the same Parquet/ORC files and external tables through the Metastore — the folders you built under `${HIVE_EXT}` are the input. The later lab on table locations (`LOCATION` clause) comes after this module. The [lakehouse module (07)](../../07-lakehouse-iceberg/README.md) picks up the failed `UPDATE`/`DELETE` of section 5 and solves it with Iceberg. Advanced Hive ([module 10](../../10-advanced-hive/README.md)) covers the complex operations: complex joins, window functions and ranking, complex types, `ROLLUP`, and WKT geo data.
