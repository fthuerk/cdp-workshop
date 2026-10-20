# Trainer notes — Module 07 Lakehouse (Iceberg)

**Dry-run status:** the lab SQL has not been run end to end on the target cluster yet. Do one full run with a normal participant account in Hue (Impala editor) before the session, fix anything that differs on your CDP version, and note it in [Pitfalls](#pitfalls). Points to confirm: `UPDATE SET *` / `INSERT *` in `MERGE`, `PARTITIONED BY SPEC`, the metadata tables (`.snapshots`, `.files`, `.history`) in Impala, `EXPIRE_SNAPSHOTS(now())`, and the row counts quoted in the lab.

**Scope:** the lab uses **Hue (Impala editor)** for all SQL and the terminal (or Hue Files) for `hdfs`. Hive and Spark are deliberately not used so the group stays on the table format. Mention in the concept part that Hive and Spark read and write the same table.

## Suggested timing (~120 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: the table is a folder + Metastore entry; what is missing (file list, history, atomic change); Iceberg adds a metadata layer in the table folder (whiteboard: Metastore → `metadata_location` → metadata.json → manifest list → manifest → Parquet) |
| 10–15 | Set up Hue and the terminal; section 0: source tables |
| 15–30 | Section 1: idempotent loads by hand. Let participants feel the effort, do not explain every statement twice |
| 30–42 | Section 2: Iceberg table and files; **walk the room** while they read the `metadata.json` |
| 42–54 | Section 3: `UPDATE`/`DELETE`/`MERGE`, delete files on HDFS |
| 54–57 | Short break |
| 57–67 | Section 4: history and time travel |
| 67–77 | Section 5: snapshot isolation; live demo [demos.md](demos.md) section 1 |
| 77–97 | Section 6: joins (the snapshot diff is the highlight) |
| 97–107 | Section 7: rollback and expire |
| 107–112 | Section 8: where Iceberg fits |
| 112–120 | `check.sh`, outlook |

If you run short, shorten section 1 (run only the partition overwrite and the merge by rewriting, skip drop/recover) and section 6 (semi/anti, range join, snapshot diff). If you split into two sessions, break after section 3.

## Check-question answers

1. **Overwrite vs insert (1):** The result of `INSERT OVERWRITE` depends only on the source, not on what was there; `INSERT INTO` adds to the existing data, so a retry duplicates. A dynamic overwrite replaces only the partitions that appear in the `SELECT`: a station that is in the table but missing from the source keeps its **stale** partition. Fix: overwrite explicit partitions, or drop partitions that should disappear.
2. **Which file to change (2):** There is none — Parquet files and delete files are immutable, and the Metastore only knows the pointer `metadata_location`. A reader opens the `metadata.json` it points to, then the manifest list and manifests, and reads exactly the listed data (and delete) files. A "change" is a new set of files plus a new `metadata.json` that lists them; the commit is the switch of the pointer. Nobody can edit a row in place.
3. **Equivalent of delta folders (3):** Delete files (position deletes) and new data files, tracked in manifests and snapshots. Readers combine data and delete files. Cleanup: compaction rewrites data and delete files into fewer, larger files (`OPTIMIZE TABLE` in Impala, Spark `rewrite_data_files`), and `EXPIRE_SNAPSHOTS` removes files that no snapshot needs. Unlike Hive ACID tables, compaction of Iceberg tables does not run on its own: schedule it.
4. **History (4):** The snapshot list tells you who changed what and when, and lets you read any past state without a copy; the price is that old data and delete files stay on HDFS until you expire snapshots, and storage grows with every commit.
5. **Report job and commits (5):** The report sees exactly one snapshot — the one that was current when the query started. Keep the snapshot until the job is done: do not expire snapshots younger than the longest query (and use the table property `history.expire.min-snapshots-to-keep` as a safety net).
6. **Duplicate price intervals (6):** The range join multiplies the readings that fall into the overlapping hours; the row count is larger than the left table. Notice with the row-count check "compare to the left table" and with `GROUP BY key HAVING COUNT(*) > 1` on the price intervals.
7. **Right to be forgotten (7):** Delete the rows (`DELETE`), **then** expire the snapshots that still contain them (and compact so that old files are rewritten). Until both are done, the data is still readable through time travel and still on HDFS.
8. **Tables to make Iceberg first (8):** Readings that need corrections and late data (smart-meter readings), and master data with updates (stations). Raw landing files and weather/price downloads can stay external CSV/Parquet until a consumer needs history or row-level changes. There is no single right answer — ask for the reason.

## Talking points

- **One table, many engines:** nothing is exported or copied; the Metastore holds a pointer and the files are on HDFS. Hive and Spark in CDP (and Trino, Flink, …) work on the same table. The lab uses Impala only so that the format stays in focus.
- **Merge-on-read vs copy-on-write:** merge-on-read = fast writes, readers merge delete files, needs compaction; copy-on-write = slow writes (data file rewritten), fast reads. Impala is merge-on-read only; Hive and Spark can choose per operation (`write.update.mode`, …).
- **Idempotency** thread from module 04: after every statement, "can I run this twice?" — `MERGE` on a key is.
- **Data scale:** the sample tables have 15 rows; delete files and snapshots are easy to see because of it. In production you have thousands of files — mention compaction and snapshot expiry as scheduled jobs.
- **Time zones:** `FOR SYSTEM_TIME AS OF` takes UTC; all pilot data is UTC.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| `STORED AS ICEBERG` denied | Ranger storage handler policy missing (see below) |
| Impala `UPDATE`/`MERGE` unsupported | Needs Runtime 7.3.1.500 or later. On older clusters run section 3 with `UPDATE`/`DELETE` only and skip the `MERGE` |
| `INSERT OVERWRITE` on `meter_part` fails | Impala cannot write ORC; the lab uses Parquet |
| Metadata tables (`.snapshots` / `.history` / `.files`) not available | Version-dependent. Fallbacks: `DESCRIBE HISTORY` and `SHOW FILES IN`. Adjust the lab if your Impala does not support them |
| Hue prompts for variables repeatedly | The editor keeps the input fields per tab; do not open a new tab per section |
| Delete file names/numbers differ from the lab | Numbers of files depend on the cluster (parallel writers, stats). Use the `content` column of `files`, not exact counts |
| Expire removes nothing | UTC vs session time zone, or `history.expire.min-snapshots-to-keep` — see troubleshooting |
| 15+ participants commit to their own tables at the same time | No conflicts (own tables); only Impala admission-control capacity |
| Participants skip or mistype section 0 | Source tables or CSV copies missing — the section 0 block is idempotent, run it again |
| `OPTIMIZE TABLE` in the stretch fails | Version-dependent, and the user needs `ALL` on the table in Ranger |

## Ranger and permissions summary

Permissions: Hive/Impala policies on `ws_*` (create database and tables), HDFS `rwx` on `/warehouse/tablespace/external/hive/ws_*` for the workshop users (they copy files into table folders), and:

1. **Storage handler policy:** in the Hadoop SQL service edit the policy "all - storage-type, storage-url": storage-type `iceberg`, storage-url `*`, permission *RW Storage* for the workshop users (or `public`). Without it, creating or altering an Iceberg table fails.
2. **HDFS:** Impala runs as the `impala` user, which already has access to the warehouse; participants need HDFS access to **look at** the table folders.
3. **Compaction (stretch):** `ALL` on the table for the user who compacts.

## Admin

[setup/setup.sh](../setup/setup.sh) only checks the prerequisites (it creates no folders). Participant databases and Iceberg tables live in the Hive warehouse; drop the `ws_<user>` databases (`DROP DATABASE … CASCADE`). Iceberg table folders under `/warehouse/tablespace/external/hive/ws_<user>.db/ice_*` may remain if the tables are not purged — check `external.table.purge` and delete the folders by hand.

## After module

Advanced Hive (module 10) builds on the joins of section 6: window functions and ranking, bucketing, and performance tuning. Spark module (06, planned): Spark reads and writes the same Iceberg tables. Not covered in the lab: Hive and Spark access to the table, copy-on-write, schema and partition evolution (stretch), branches and tags, and (from Runtime 7.3.2 SP1, Technical Preview) format version 3 with deletion vectors.
