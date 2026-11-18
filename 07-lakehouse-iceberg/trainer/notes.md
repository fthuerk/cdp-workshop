# Trainer notes — Module 07 Lakehouse (Iceberg)

**Dry-run status:** the lab SQL has not been run end to end on the target cluster yet. Do one full run with a normal participant account in Hue (Impala editor) before the session, fix anything that differs on your CDP version, and note it in [Pitfalls](#pitfalls). Points to confirm: `SET PARTITION SPEC (station_id, HOUR(ts))` and `spec_id` in `.files` (stretch), `CREATE TABLE … PARTITIONED BY SPEC … STORED BY ICEBERG AS SELECT`, the `MERGE` with an inline `UNION ALL` source and an `INSERT (column list)`, the metadata tables (`.snapshots`, `.files`, `.history`) in Impala, `EXPIRE_SNAPSHOTS(now())`, and the row counts quoted in the lab.

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

## Check-question answers

1. **Which file to change (1):** There is none — Parquet files and delete files are immutable, and the Metastore only knows the pointer `metadata_location`. A reader opens the `metadata.json` it points to, then the manifest list and manifests, and reads exactly the listed data (and delete) files. A "change" is a new set of files plus a new `metadata.json` that lists them; the commit is the switch of the pointer. Nobody can edit a row in place.
2. **Equivalent of delta folders (2):** Delete files (position deletes) and new data files, tracked in manifests and snapshots. Readers combine data and delete files. Cleanup: compaction rewrites data and delete files into fewer, larger files (`OPTIMIZE TABLE` in Impala, Spark `rewrite_data_files`), and `EXPIRE_SNAPSHOTS` removes files that no snapshot needs. Unlike Hive ACID tables, compaction of Iceberg tables does not run on its own: schedule it.
3. **Report job and commits (3):** The report sees exactly one snapshot — the one that was current when the query started. Keep the snapshot until the job is done: do not expire snapshots younger than the longest query (and use the table property `history.expire.min-snapshots-to-keep` as a safety net). The cost of history: old data and delete files stay on HDFS until you expire snapshots, so storage grows with every commit.
4. **Right to be forgotten (4):** Delete the rows (`DELETE`), **then** expire the snapshots that still contain them (and compact so that old files are rewritten). Until both are done, the data is still readable through time travel and still on HDFS.
5. **Tables to make Iceberg first (5):** Readings that need corrections and late data (smart-meter readings), and master data with updates (stations). Raw landing files and weather/price downloads can stay external CSV/Parquet until a consumer needs history or row-level changes. There is no single right answer — ask for the reason.

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
