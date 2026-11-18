# Trainer notes — Module 07 Lakehouse (Iceberg)

**Dry-run status:** the lab SQL has not been run end to end on the target cluster yet. Do one full run with a normal participant account in Hue (Impala editor) before the session, fix anything that differs on your CDP version, and note it in [Pitfalls](#pitfalls). Points to confirm: `SET PARTITION SPEC (station_id, HOUR(ts))` and `spec_id` in `.files` (stretch), `CREATE TABLE … PARTITIONED BY SPEC … STORED BY ICEBERG AS SELECT`, the `MERGE` with the change table as source and an `INSERT (column list)`, `INSERT OVERWRITE … VALUES` into an external Parquet table, the metadata tables (`.snapshots`, `.files`, `.history`) in Impala, `EXPIRE_SNAPSHOTS(now())`, and the row counts quoted in the lab.

**Scope:** the lab uses **Hue (Impala editor)** for all SQL and the terminal (or Hue Files) for `hdfs`. Hive and Spark are deliberately not used so the group stays on the table format. Mention in the concept part that Hive and Spark read and write the same table.

## Suggested timing (~60 min)

| Minutes | Activity |
|---------|----------|
| 0–8 | Concept: the table is a folder + Metastore entry; what is missing (file list, history, atomic change); Iceberg adds a metadata layer in the table folder (whiteboard: Metastore → `metadata_location` → metadata.json → manifest list → manifest → Parquet) |
| 8–13 | Set up Hue and the terminal; section 0: source table |
| 13–23 | Section 1: Iceberg table and files; **walk the room** while they read the `metadata.json` |
| 23–38 | Section 2: `UPDATE`/`DELETE`/`MERGE`, delete files on HDFS |
| 38–50 | Section 3: time travel, snapshot isolation (live demo [tutorial-iceberg.md](tutorial-iceberg.md) A1), snapshot diff |
| 50–57 | Section 4: rollback and expire |
| 57–60 | Section 5: where Iceberg fits; `check.sh` |

If you run short, skip the snapshot diff in section 3 and the stretch. The manual patterns on external tables (partition overwrite, rewrite, merge by rewriting) are not part of this module; if the audience asks, show `INSERT OVERWRITE … PARTITION` and the stale-partition trap as a short demo.

## Talking points

- **One table, many engines:** nothing is exported or copied; the Metastore holds a pointer and the files are on HDFS. Hive and Spark in CDP (and Trino, Flink, …) work on the same table. The lab uses Impala only so that the format stays in focus.
- **Merge-on-read vs copy-on-write:** merge-on-read = fast writes, readers merge delete files, needs compaction; copy-on-write = slow writes (data file rewritten), fast reads. Impala is merge-on-read only; Hive and Spark can choose per operation (`write.update.mode`, …).
- **Idempotency** thread from module 04: "can I run this twice?" — `MERGE` on a key is.
- **Data scale:** the sample tables have 15 rows; delete files and snapshots are easy to see because of it. In production you have thousands of files — mention compaction and snapshot expiry as scheduled jobs.
- **Time zones:** `FOR SYSTEM_TIME AS OF` takes UTC; all pilot data is UTC.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| `STORED BY ICEBERG` denied | Ranger storage handler policy missing (see below) |
| Impala `UPDATE`/`MERGE` unsupported | Needs Runtime 7.3.1.500 or later. On older clusters run section 2 with `UPDATE`/`DELETE` only and skip the `MERGE` |
| Metadata tables (`.snapshots` / `.history` / `.files`) not available | Version-dependent. Fallbacks: `DESCRIBE HISTORY` and `SHOW FILES IN`. Adjust the lab if your Impala does not support them |
| Hue prompts for variables repeatedly | The editor keeps the input fields per tab; do not open a new tab per section |
| Delete file names/numbers differ from the lab | Numbers of files depend on the cluster (parallel writers, stats). Use the `content` column of `files`, not exact counts |
| Expire removes nothing | UTC vs session time zone, or `history.expire.min-snapshots-to-keep` — see troubleshooting |
| 15+ participants commit to their own tables at the same time | No conflicts (own tables); only Impala admission-control capacity |
| Participants skip or mistype section 0 | Source table or CSV copy missing — the section 0 block is idempotent, run it again |
| `SET PARTITION SPEC` or the `.files` column `spec_id` fails in the stretch | Version-dependent; check with `SHOW CREATE TABLE ice_meter` and `hdfs dfs -ls -R` instead |
| `OPTIMIZE TABLE` in the stretch fails | Version-dependent, and the user needs `ALL` on the table in Ranger |

## Ranger and permissions summary

Permissions: Hive/Impala policies on `{USER}` (create database and tables), HDFS `rwx` on `/warehouse/tablespace/external/hive/{USER}.db` for the workshop users (they copy the CSV file into the table folder), and:

1. **Storage handler policy:** in the Hadoop SQL service edit the policy "all - storage-type, storage-url": storage-type `iceberg`, storage-url `*`, permission *RW Storage* for the workshop users (or `public`). Without it, creating or altering an Iceberg table fails.
2. **HDFS:** Impala runs as the `impala` user, which already has access to the warehouse; participants need HDFS access to **look at** the table folders.
3. **Compaction (stretch):** `ALL` on the table for the user who compacts.

## Admin

[setup/setup.sh](../setup/setup.sh) only checks the prerequisites (it creates no folders). Participant databases and Iceberg tables live in the Hive warehouse; drop the `<user>` databases (`DROP DATABASE … CASCADE`). Iceberg table folders under `/warehouse/tablespace/external/hive/<user>.db/ice_meter` may remain if the tables are not purged — check `external.table.purge` and delete the folders by hand.

## After module

Advanced Hive (module 10) covers joins, window functions and ranking, bucketing, and performance tuning. Spark module (06, planned): Spark reads and writes the same Iceberg tables. Not covered in the lab, but in [tutorial-iceberg.md](tutorial-iceberg.md): Hive and Spark access to the table and their differences from Impala (Part C), copy-on-write, schema and partition evolution, metadata tables, maintenance, branches and tags (Part B). Not covered anywhere: and (from Runtime 7.3.2 SP1, Technical Preview) format version 3 with deletion vectors.

## Answers to the check questions of the lab

One entry per check question, in lab order.

### Section 1 — Which file does `metadata_location` point to, and what does a reader do with it? Which file would you have to change to make an old row disappear — and why can nobody do that in place?

`metadata_location` (a table property in the Metastore) points to the newest `*.metadata.json`. A reader opens it, finds the current snapshot and its manifest list (`snap-*.avro`), reads the manifests (`*-m0.avro`) and then exactly the data files (and delete files) that they list. To make an old row disappear you would have to change the Parquet data file that contains it — and nobody can do that in place: Parquet files and delete files are immutable, and so are the metadata files of older snapshots. A "change" is a new set of files plus a new `metadata.json` that lists them; the commit is the switch of the pointer in the Metastore.

### Section 2 — On a Hive managed (ACID) table, `UPDATE` and `DELETE` write `delta_` and `delete_delta_` folders. What is the equivalent here, and who cleans it up?

Delete files (position deletes: file path and row position of every deleted row) and new data files, tracked in manifests and snapshots. Readers combine data and delete files (merge-on-read). Cleanup is **your** job: compaction (`OPTIMIZE TABLE` in Impala, `rewrite_data_files` in Spark) rewrites data and delete files into fewer, larger files, and `EXPIRE_SNAPSHOTS` removes the files that no snapshot needs any more. Unlike Hive ACID tables, nothing compacts on its own — schedule both.

### Section 3 — A report job runs for 20 minutes while the pipeline commits every 5 minutes. Which data does the report see — and what must you keep so that the report does not fail?

The report sees exactly one snapshot: the one that was current when the query started. The commits during the 20 minutes (about four) are invisible to it; the next run sees them. To keep it from failing, do not expire that snapshot (and its files) while the query runs: keep snapshots at least as long as your longest query, plus a margin, and use `history.expire.min-snapshots-to-keep` as a safety net. The price of history is storage: old files stay on HDFS until the snapshots are expired.

### Section 4 — A "right to be forgotten" request means a customer's rows must disappear from the table and from its history. Which two steps are needed?

1. `DELETE` the customer's rows — this removes them from the current snapshot only.
2. **Expire** the snapshots that still contain them (`EXPIRE_SNAPSHOTS`), ideally after a compaction so that the old data files are rewritten and removed.

Until both are done the rows are still readable through time travel and still on HDFS.

### Section 5 — Which tables of your pilot would you make Iceberg tables first, and which stay external CSV or Parquet?

There is no single right answer — ask for the reason. A good answer: **Iceberg first** for smart-meter readings (corrections, late data, audits and reproducible reports need row-level changes and history) and for master data that is updated (stations). **External CSV/Parquet** for raw landing files, and for weather and market-price downloads, until a consumer needs history or row-level changes; the same goes for tiny reference tables nobody changes.
