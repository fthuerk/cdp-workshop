# Trainer notes — Module 07 Lakehouse (Iceberg)

**Dry-run status:** the lab SQL has not been run end to end on the target cluster yet. Do one full run with a normal participant account in all three engines before the session, fix anything that differs on your CDP version, and note it in [Pitfalls](#pitfalls). The per-engine feature table in lab section 0 is taken from the Cloudera Runtime 7.3.2 documentation; confirm each cell on your cluster.

## Suggested timing (~150 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: the table is a folder + Metastore entry; what is missing (file list, history, atomic change); Iceberg adds a metadata layer in the table folder (whiteboard: Metastore → `metadata_location` → metadata.json → manifest list → manifest → Parquet) |
| 10–15 | Section 0: Beeline, source tables, the engine table |
| 15–30 | Section 1: idempotent loads by hand. Let participants feel the effort, do not explain every statement twice |
| 30–42 | Section 2: Iceberg table and files; **walk the room** while they read the `metadata.json` |
| 42–54 | Section 3: Hive `UPDATE`/`DELETE`/`MERGE`, delete files on HDFS |
| 54–57 | Short break |
| 57–67 | Section 4: Impala |
| 67–77 | Section 5: Spark (most likely to hit setup problems: have the start command ready) |
| 77–89 | Section 6: history and time travel in three engines |
| 89–97 | Section 7: snapshot isolation; live demo [demos.md](demos.md) section 1 |
| 97–122 | Section 8: advanced joins (the snapshot diff is the highlight) |
| 122–132 | Section 9: rollback and expire |
| 132–140 | Section 10: engine comparison discussion |
| 140–150 | `check.sh`, outlook |

If you run short, shorten section 1 (run only the partition overwrite and the merge by rewriting, skip drop/repair) and section 8 (semi/anti, range join, snapshot diff). If you split into two sessions, break after section 5.

## Check-question answers

1. **Overwrite vs insert (1):** The result of `INSERT OVERWRITE` depends only on the source, not on what was there; `INSERT INTO` adds to the existing data, so a retry duplicates. A dynamic overwrite replaces only the partitions that appear in the `SELECT`: a station that is in the table but missing from the source keeps its **stale** partition. Fix: overwrite explicit partitions, or drop partitions that should disappear.  
2. **Which file to change (2):** There is none — Parquet files and delete files are immutable, and the Metastore only knows the pointer `metadata_location`. A "change" is a new set of files plus a new `metadata.json` that lists them; the commit is the switch of the pointer. Nobody can edit a row in place.  
3. **Equivalent of delta folders (3):** Delete files (position deletes) and new data files, tracked in manifests and snapshots. Readers combine data and delete files. Cleanup: compaction rewrites data and delete files into fewer, larger files (Spark `rewrite_data_files`, Hive/Impala compaction where available — see the 7.3.2 docs), and `EXPIRE_SNAPSHOTS` removes files that no snapshot needs. Unlike Hive ACID tables, compaction of Iceberg tables does not run on its own: schedule it.  
4. **Impala `DELETE` files (4):** It wrote a delete file (Parquet) naming the deleted rows; it removed nothing. The old data files are still referenced by older snapshots (and by the current one — readers apply the delete file).  
5. **Why no locking (5):** All engines agree on the table format: immutable files, a snapshot per commit, and an atomic swap of the metadata pointer in the Metastore. Each writer prepares its files without touching anyone else's, and the commit succeeds only if the table is still in the state the writer started from (optimistic concurrency). Readers just read one snapshot.  
6. **Schema of an old snapshot (6):** Hive and Impala read old snapshots with the **current** schema, so a column added later shows `NULL` for old rows. Spark's `VERSION AS OF` / `TIMESTAMP AS OF` uses the schema of the snapshot (columns added later are missing) — mention the difference if somebody tries it.  
7. **Report job and commits (7):** The report sees exactly one snapshot — the one that was current when the query started. Keep the snapshot until the job is done: do not expire snapshots younger than the longest query (and the table property `history.expire.min-snapshots-to-keep` as a safety net).  
8. **Duplicate price intervals (8):** The range join multiplies the readings that fall into the overlapping hours; the row count is larger than the left table. Notice with the row-count check "compare to the left table" and with `GROUP BY key HAVING COUNT(*) > 1` on the price intervals.  
9. **Right to be forgotten (9):** Delete the rows (`DELETE`), **then** expire the snapshots that still contain them (and compact so that old files are rewritten). Until both are done, the data is still readable through time travel and still on HDFS.  
10. **Tables to make Iceberg first (10):** Readings that need corrections and late data (smart-meter readings), and master data with updates (stations). Raw landing files and weather/price downloads can stay external CSV/Parquet until a consumer needs history or row-level changes. There is no single right answer — ask for the reason.

## Talking points

- **One table, three engines:** the point of section 4–6. Nothing is exported or copied; the Metastore holds a pointer and the files are on HDFS. Stress that other engines (Trino, Flink, …) work the same way.  
- **Merge-on-read vs copy-on-write:** merge-on-read = fast writes, readers merge delete files, needs compaction; copy-on-write = slow writes (data file rewritten), fast reads. Hive and Spark choose per operation (`write.update.mode`, …), Impala is merge-on-read only.  
- **Idempotency** thread from module 04: after every statement, "can I run this twice?" — `MERGE` on a key is.  
- **Data scale:** the sample tables have 15 rows; delete files and snapshots are easy to see because of it. In production you have thousands of files — mention compaction and snapshot expiry as scheduled jobs.  
- **Time zones:** `FOR SYSTEM_TIME AS OF` takes UTC; all pilot data is UTC.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| `STORED BY ICEBERG` denied | Ranger storage handler policy missing (see below) |
| Hive creates the table but Impala cannot update it | Table created with ORC or v1. The lab sets `STORED AS PARQUET`, `format-version=2`, and the delete-format property — check `SHOW TBLPROPERTIES` |
| Impala `UPDATE`/`MERGE` unsupported | Needs Runtime 7.3.1.500 or later. On older clusters run section 4 with `DELETE` only or skip the Impala `UPDATE` |
| Spark `UPDATE`/`MERGE`/`CALL` parse error | Extensions missing — start command in lab section 5. Some clusters already set `spark.sql.extensions` in `spark-defaults.conf`; passing it again is harmless |
| Spark cannot access Iceberg metadata tables | Use the fully qualified `spark_catalog.<db>.<table>.snapshots` with the session catalog |
| `.snapshots` / `.history` / `.files` metadata tables not available in Hive | Version-dependent. Fallbacks: Impala `DESCRIBE HISTORY` and `SHOW FILES IN`, Spark metadata tables. Adjust section 2/3/6 of the lab if your Hive does not support them |
| Delete file names/numbers differ from the lab | Numbers of files depend on the cluster (parallel writers, stats). Use the `content` column of `files`, not exact counts |
| Expire removes nothing | UTC vs session time zone, or `history.expire.min-snapshots-to-keep` — see troubleshooting |
| 15+ participants commit to their own tables at the same time | No conflicts (own tables); only Tez/YARN queue capacity — as in module 04 |
| Participants skip or mistype section 0 | Source tables or CSV copies missing — the section 0 block is idempotent, run it again |
| Hive Iceberg `ALTER … COMPACT` / Spark `rewrite_data_files` in the stretch fail | The user needs `ALL` on the table in Ranger (compaction permission) |

## Ranger and permissions summary

Permissions: Hive policies on `ws_*` (create database and tables), HDFS `rwx` on `/warehouse/tablespace/external/hive/ws_*` for the workshop users (they copy files into table folders), and:

1. **Storage handler policy:** in the Hadoop SQL service edit the policy "all - storage-type, storage-url": storage-type `iceberg`, storage-url `*`, permission *RW Storage* for the workshop users (or `public`). Without it, creating or altering an Iceberg table fails.  
2. **HDFS for Spark and Impala:** Spark reads and writes the table files as the participant, so the HDFS policy above matters. Impala runs as the `impala` user, which already has access to the warehouse.  
3. **Compaction (stretch):** `ALL` on the table for the user who compacts.

## Admin

[setup/setup.sh](../setup/setup.sh) only checks the prerequisites (it creates no folders). Participant databases and Iceberg tables live in the Hive warehouse; drop the `ws_<user>` databases (`DROP DATABASE … CASCADE`). Iceberg table folders under `/warehouse/tablespace/external/hive/ws_<user>.db/ice_*` may remain if the tables are not purged — check `external.table.purge` and delete the folders by hand.

## After module

Advanced Hive (module 10) builds on the joins of section 8: window functions and ranking, bucketing, and performance tuning. Spark module (05, planned): Spark reads and writes the same Iceberg tables; the `spark3-shell` start command of section 5 is reused. Not covered in the lab: schema and partition evolution (stretch), branches and tags, and (from Runtime 7.3.2 SP1, Technical Preview) format version 3 with deletion vectors in Hive and Spark.
