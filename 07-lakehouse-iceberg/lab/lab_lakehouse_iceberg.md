# Lakehouse hands-on lab (Iceberg)

You know external tables from the Hive module: **a folder plus a definition in the Metastore**. Which files belong to the table, what changed, and who may see half-finished work is not tracked anywhere — that is why `UPDATE` and `DELETE` fail on them. **Apache Iceberg** adds the missing layer *inside the table folder*, as metadata files that every engine can read. This lab is about exactly that layer.

The lab uses **two tables**: `grid_measurements_csv` (external, the source) and `ice_meter` (Iceberg, the table you work on). Run the sections in order.

| Tool | Used for |
|------|----------|
| **Hue → Editor → Impala** | All SQL of the lab |
| **Terminal** on the edge node (or Hue **Files**) | `hdfs` commands: you look at the files behind the Iceberg table |

Why only Impala? The lab is about the table format, not about engines. Impala creates Iceberg tables, runs `UPDATE`, `DELETE`, and `MERGE`, time travel, rollback, and snapshot expiry. Hive and Spark in CDP work on the very same table.

---

## Set up your tools

**Terminal.** Set your Kerberos identity once. `WORKSHOP_USER` is the short name you use with `kinit`:

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
```

The `kinit` asks for your password, so it has its own block. Then set the paths. `HIVE_EXT` is the default external folder of your database (one sub-folder per table), `ICE_META` the folder of the Iceberg table you create in section 1:

```bash
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export HIVE_EXT="/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db"   # adjust if needed
export ICE_META="${HIVE_EXT}/ice_meter"
export IMPALA_OPTS="<impala-shell-options-from-handout>"   # only needed for check.sh at the end
```

**Hue.** Open **Editor → Impala** (URL from your handout) and paste the `sql` blocks unchanged. Run a statement with **Ctrl+Enter**; to run several statements one after another, select them first.

The SQL contains placeholders like `${ws_user}`. As soon as the editor contains one, Hue shows an **input field** below the editor. Type your `WORKSHOP_USER` into `ws_user`. Later sections use `${snap_first}` and `${snap_good}` the same way: paste a snapshot ID from a query result into the field.

Hue can also show HDFS: open **Files** and type a path such as `/warehouse/tablespace/external/hive/<your_username>.db`. Every `hdfs dfs -ls` of the lab has this equivalent.

---

## 0. The source table

**Goal:** One small external table with the readings of three transformer stations. All statements are safe to repeat (and the table may exist from the Hive module).

```sql
CREATE DATABASE IF NOT EXISTS ${ws_user};
USE ${ws_user};

CREATE EXTERNAL TABLE IF NOT EXISTS grid_measurements_csv (
  ts_utc STRING,
  station_id STRING,
  device_id STRING,
  phase STRING,
  active_power_kw DOUBLE,
  reactive_power_kvar DOUBLE,
  voltage_v DOUBLE,
  current_a DOUBLE,
  power_factor DOUBLE,
  frequency_hz DOUBLE,
  transformer_load_pct DOUBLE,
  quality_flag STRING,
  event_code STRING,
  comm_status STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');
```

```bash
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv" "${HIVE_EXT}/grid_measurements_csv/"
```

```sql
REFRESH grid_measurements_csv;
SELECT station_id, COUNT(*) FROM grid_measurements_csv GROUP BY station_id ORDER BY station_id;
```

You should see 5 readings for each of `TS-101`, `TS-204`, and `TS-305`.

---

## 1. An Iceberg table — and the files behind it

**Goal:** Create the Iceberg table and find out what Iceberg stores on HDFS.

`STORED BY ICEBERG` selects the table format and `PARTITIONED BY SPEC (station_id)` is Iceberg's partitioning clause. An Iceberg table is created with a plain `CREATE TABLE` (no `EXTERNAL`); `format-version` 2, which row-level changes need, is the default. Impala writes Parquet files and handles row-level changes as **merge-on-read** (you see what that means in section 2). The `CREATE TABLE … AS SELECT` copies the source table in one step:

```sql
CREATE TABLE ice_meter
PARTITIONED BY SPEC (station_id)
STORED BY ICEBERG
AS SELECT * FROM grid_measurements_csv;

SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
DESCRIBE FORMATTED ice_meter;
SHOW TBLPROPERTIES ice_meter;
```

In the output look for the table type, the `metadata_location` property, the partition transform (`station_id`, `IDENTITY`), and the `Location`. Unlike a partitioned external table there is no `RECOVER PARTITIONS`: Iceberg tracks partitions and files itself.

Now look at HDFS (terminal):

```bash
hdfs dfs -ls -R "${ICE_META}"
```

You should see two folders:

- `data/` — Parquet files in one sub-folder per station. These are normal Parquet files.
- `metadata/` — files that only Iceberg writes: `*.metadata.json` (the table definition), `snap-*.avro` (the **manifest list** of one snapshot) and `*-m0.avro` (the **manifest**, a list of data files with row counts and column statistics).

Each change to the table writes a **new** `*.metadata.json` and then switches the pointer `metadata_location` in the Metastore to it — that single switch is the commit. Read the newest one; it is plain JSON:

```bash
META=$(hdfs dfs -ls "${ICE_META}/metadata" | awk '/metadata.json/ {print $NF}' | sort | tail -1)
hdfs dfs -cat "${META}" | head -70
```

Find `format-version`, the `schemas`, the `partition-specs`, and the `snapshots` with `manifest-list` and `summary` (`added-data-files`, `added-records`). The Avro files are binary; read their content with SQL instead. The `files` metadata table lists the data files of the current snapshot:

```sql
SELECT content, file_path, record_count, file_size_in_bytes
FROM ${ws_user}.ice_meter.files;
```

`content = 0` means a data file. Compare the paths with your `hdfs dfs -ls -R` output.

**Check question:** Which file does `metadata_location` point to, and what does a reader do with it? Which file would you have to change to make an old row disappear — and why can nobody do that in place?

---

## 2. UPDATE, DELETE, MERGE — and what happens on HDFS

**Goal:** Change single rows with plain SQL and watch the files.

The `UPDATE` and `DELETE` that fail on external tables now work. Station `TS-204` is in maintenance and was commissioned at `08:30`, so its first two readings are test data:

```sql
UPDATE ice_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM ice_meter WHERE station_id = 'TS-305' AND event_code = 'HIGH_LOAD';
UPDATE ice_meter SET comm_status = 'MAINTENANCE' WHERE station_id = 'TS-204';
DELETE FROM ice_meter WHERE station_id = 'TS-204' AND ts_utc < '2026-01-15T08:30:00Z';

SELECT station_id, quality_flag, comm_status, COUNT(*)
FROM ice_meter GROUP BY station_id, quality_flag, comm_status ORDER BY station_id;
```

List the files again (terminal) and compare with section 1:

```bash
hdfs dfs -ls -R "${ICE_META}/data"
hdfs dfs -ls "${ICE_META}/metadata"
```

The old data files are **still there**, unchanged. With merge-on-read Iceberg writes small **delete files** next to them (Parquet files that list the file path and row position of every deleted row); an `UPDATE` writes a delete file plus a new data file with the new row versions. Readers combine data and delete files. Ask the `files` table which is which:

```sql
SELECT content, file_path, record_count FROM ${ws_user}.ice_meter.files ORDER BY content, file_path;
```

`content = 1` means a **position delete** file. Every statement also added a `*.metadata.json` file and a snapshot.

Now a `MERGE`. A late delivery corrects two readings (`TS-101` at `08:45`, `TS-204` at `09:00`) and brings two new ones (`09:15` of both stations). The source is an inline query, so no further table is needed:

```sql
MERGE INTO ice_meter AS t
USING (
  SELECT '2026-01-15T08:45:00Z' AS ts_utc, 'TS-101' AS station_id, CAST(203.9 AS DOUBLE) AS active_power_kw, 'OK' AS quality_flag, 'ONLINE' AS comm_status
  UNION ALL
  SELECT '2026-01-15T09:15:00Z', 'TS-101', CAST(199.5 AS DOUBLE), 'OK', 'ONLINE'
  UNION ALL
  SELECT '2026-01-15T09:00:00Z', 'TS-204', CAST(111.0 AS DOUBLE), 'OK', 'MAINTENANCE'
  UNION ALL
  SELECT '2026-01-15T09:15:00Z', 'TS-204', CAST(108.9 AS DOUBLE), 'OK', 'MAINTENANCE'
) AS s
ON t.station_id = s.station_id AND t.ts_utc = s.ts_utc
WHEN MATCHED THEN UPDATE SET
  active_power_kw = s.active_power_kw, quality_flag = s.quality_flag, comm_status = s.comm_status
WHEN NOT MATCHED THEN INSERT (ts_utc, station_id, active_power_kw, quality_flag, comm_status)
  VALUES (s.ts_utc, s.station_id, s.active_power_kw, s.quality_flag, s.comm_status);

SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
SELECT ts_utc, quality_flag FROM ice_meter WHERE station_id = 'TS-101' ORDER BY ts_utc;
```

You should see 6 readings for `TS-101`, 4 for `TS-204`, and 3 for `TS-305` (13 rows), with `08:45` of `TS-101` now `OK`. The new readings have `NULL` in the columns the delivery did not contain. Run the `MERGE` a second time and count again: still 13. A `MERGE` on a unique key is idempotent.

Look at what happened so far. Each statement is one snapshot:

```sql
DESCRIBE HISTORY ice_meter;
SELECT committed_at, snapshot_id, operation FROM ${ws_user}.ice_meter.snapshots ORDER BY committed_at;
```

**Check question:** On a Hive managed (ACID) table, `UPDATE` and `DELETE` write `delta_` and `delete_delta_` folders. What is the equivalent here, and who cleans it up?

---

## 3. Time travel and snapshot isolation

**Goal:** Read the table as it was before the changes, and see what a change does to the files of an earlier snapshot.

Each commit created a **snapshot**: a complete, consistent state of the table. Get the ID of the first snapshot — the table as you loaded it — and paste it into the `snap_first` field of Hue:

```sql
SELECT snapshot_id, committed_at FROM ${ws_user}.ice_meter.snapshots ORDER BY committed_at LIMIT 1;
```

Ask for the table as of that snapshot, and for the table now:

```sql
SELECT station_id, COUNT(*) AS n FROM ice_meter FOR SYSTEM_VERSION AS OF ${snap_first} GROUP BY station_id ORDER BY station_id;
SELECT station_id, COUNT(*) AS n FROM ice_meter GROUP BY station_id ORDER BY station_id;
```

You should see 5 / 5 / 5 rows for the first snapshot and 6 / 4 / 3 now. See the old and the new state of one reading:

```sql
SELECT ts_utc, quality_flag, comm_status FROM ice_meter FOR SYSTEM_VERSION AS OF ${snap_first}
WHERE station_id = 'TS-101' AND ts_utc = '2026-01-15T08:45:00Z';
SELECT ts_utc, quality_flag, comm_status FROM ice_meter
WHERE station_id = 'TS-101' AND ts_utc = '2026-01-15T08:45:00Z';
```

You can also travel by **time**: `FOR SYSTEM_TIME AS OF '<timestamp>'` (UTC) or `FOR SYSTEM_TIME AS OF now() - INTERVAL 30 MINUTES`.

**Snapshot isolation.** The listing of section 2 showed it already: no change modified or removed a file of an earlier snapshot. Therefore:

- A query reads the table metadata **once**, at the start, and then reads exactly the files of that snapshot. A commit that happens while the query runs creates new files and a new snapshot; the running query never sees it.
- A commit is one atomic step (the pointer in the Metastore). Readers see the table before or after a change, never half of it — unlike a partition that is being overwritten.
- Writers do not block readers. Two writers that change the same table at once use **optimistic concurrency**: if another commit came first, one writer retries or fails — it never silently overwrites the other. Your instructor shows this live.

**What changed? Join two snapshots.** Only a table format lets you do this: a `FULL OUTER JOIN` of the table as of `snap_first` with the table now, on the key of a reading:

```sql
WITH at_first AS (SELECT * FROM ice_meter FOR SYSTEM_VERSION AS OF ${snap_first}),
     at_now AS (SELECT * FROM ice_meter)
SELECT COALESCE(c.station_id, o.station_id) AS station_id,
       COALESCE(c.ts_utc, o.ts_utc) AS ts_utc,
       CASE WHEN o.ts_utc IS NULL THEN 'inserted'
            WHEN c.ts_utc IS NULL THEN 'deleted'
            WHEN o.quality_flag <> c.quality_flag OR o.comm_status <> c.comm_status
                 OR o.active_power_kw <> c.active_power_kw THEN 'changed'
            ELSE 'unchanged' END AS change
FROM at_first o
FULL OUTER JOIN at_now c ON o.station_id = c.station_id AND o.ts_utc = c.ts_utc
ORDER BY station_id, ts_utc;
```

You should see 17 rows: 7 unchanged, 4 changed (`TS-101` at `08:45` and the three remaining original readings of `TS-204`), 4 deleted (two `HIGH_LOAD` readings of `TS-305`, two early readings of `TS-204`), and 2 inserted (the `09:15` readings). It is a complete audit trail of section 2 from one query. The price: old files stay on HDFS until you expire the snapshots (section 4).

**Check question:** A report job runs for 20 minutes while the pipeline commits every 5 minutes. Which data does the report see — and what must you keep so that the report does not fail?

---

## 4. Undo and clean up — rollback and expire snapshots

**Goal:** Recover from a wrong statement, then remove history you no longer need and see the files go.

First remember the good state: get the ID of the current snapshot and paste it into the `snap_good` field of Hue:

```sql
SELECT snapshot_id, committed_at FROM ${ws_user}.ice_meter.snapshots ORDER BY committed_at DESC LIMIT 1;
```

Then make a mistake. Somebody wanted to delete the `REVIEWED` readings, but typed the wrong condition:

```sql
DELETE FROM ice_meter WHERE quality_flag = 'OK';
SELECT COUNT(*) FROM ice_meter;
```

Almost every reading had the flag `OK`, so the table is nearly empty. Roll the table back to the good snapshot — a metadata operation, no data is copied:

```sql
ALTER TABLE ice_meter EXECUTE ROLLBACK(${snap_good});
SELECT COUNT(*) FROM ice_meter;
SELECT snapshot_id, parent_id, is_current_ancestor FROM ${ws_user}.ice_meter.history ORDER BY made_current_at;
```

The count is 13 again. In the history the wrong `DELETE` is still listed, but with `is_current_ancestor = false`: it is not part of the table's lineage any more. On an external table the same mistake would have been permanent.

Now the cleanup. Every snapshot keeps its files. Count the files, expire everything older than now, and count again:

```bash
hdfs dfs -count "${ICE_META}/data" "${ICE_META}/metadata"
```

```sql
ALTER TABLE ice_meter EXECUTE EXPIRE_SNAPSHOTS(now());
```

```bash
hdfs dfs -count "${ICE_META}/data" "${ICE_META}/metadata"
hdfs dfs -ls -R "${ICE_META}/data"
```

`-count` prints directories, files, and bytes. The number of files under `data` goes down: Iceberg deletes data and delete files that no remaining snapshot refers to. Only the current snapshot is left, so time travel to `snap_first` now fails — this error is expected:

```sql
SELECT COUNT(*) FROM ice_meter FOR SYSTEM_VERSION AS OF ${snap_first};
```

Expiring is a decision about **how long you want to keep history** — for audits, for rollbacks, for GDPR deletes (an expired snapshot no longer contains the deleted person's data). A production table gets a schedule: keep the last 30 days, expire the rest.

**Check question:** A "right to be forgotten" request means a customer's rows must disappear from the table **and** from its history. Which two steps are needed?

---

## 5. Where Iceberg fits

An Iceberg table is a folder with `data/` and `metadata/` and a pointer in the Metastore. `UPDATE`, `DELETE`, and `MERGE` are plain SQL and write new files instead of changing old ones; snapshots, time travel, rollback, and expiry come with the format. Hive and Spark work on the same table — nothing is exported or copied.

Iceberg is **not** the answer for raw landing zones where files arrive from outside (keep them as external tables) and for tiny reference tables nobody changes.

**Check question:** Which tables of your pilot (smart-meter readings, market prices, weather, station master data) would you make Iceberg tables first, and which stay external CSV or Parquet?

---

## Self-check

From the repo root on the edge node, run the module check script **before** the stretch (it expects the 13 rows of section 4) (uses your Kerberos ticket, `IMPALA_OPTS`, and the tables you created):

```bash
./07-lakehouse-iceberg/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).

---

## Stretch (optional)

- **Schema and partition evolution (repartitioning):** the table is partitioned by `station_id`; now partition new data by hour as well, without rebuilding the table. A partition on time needs a timestamp column, and `ts_utc` is a string. Add one (a metadata-only change; old rows get `NULL`) and fill it:

  ```sql
  ALTER TABLE ice_meter ADD COLUMNS (ts TIMESTAMP);
  UPDATE ice_meter SET ts = CAST(REPLACE(SUBSTR(ts_utc, 1, 19), 'T', ' ') AS TIMESTAMP);
  ```

  Change the partition spec and write a new reading:

  ```sql
  ALTER TABLE ice_meter SET PARTITION SPEC (station_id, HOUR(ts));

  INSERT INTO ice_meter (ts_utc, station_id, active_power_kw, ts)
  SELECT '2026-01-15T09:30:00Z', 'TS-101', CAST(190.0 AS DOUBLE), CAST('2026-01-15 09:30:00' AS TIMESTAMP);

  SELECT spec_id, file_path FROM ${ws_user}.ice_meter.files ORDER BY spec_id, file_path;
  SELECT COUNT(*) FROM ice_meter WHERE ts >= '2026-01-15 09:00:00';
  ```

  The table now has **two partition specs**: the old files (`spec_id = 0`) stay in the old layout, the new file (`spec_id = 1`) is in a sub-folder per station **and** hour (`hdfs dfs -ls -R "${ICE_META}/data"`). Nothing was rewritten, and queries work across both layouts — the filter on `ts` is mapped to the partitions by Iceberg itself (**hidden partitioning**). With a Hive-style partitioned table you would have to create a new table and copy all data.
- **Compact small files:** every statement adds files. `OPTIMIZE TABLE ice_meter;` rewrites them into fewer, larger files (if your Runtime release supports it). List `${ICE_META}/data` before and after; the old files stay until you expire the snapshots.
