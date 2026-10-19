# Lakehouse hands-on lab (Iceberg)

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. The lab builds its own database and source tables in section 0 (a few statements; nothing from other modules is required).

You work with two tools:

| Tool | Used for |
|------|----------|
| **Hue → Editor → Impala** | All SQL of the lab |
| **Terminal** on the edge node (or Hue **Files**) | `hdfs` commands: you look at the files behind every table |

Why only Impala? The lab is about the table format, not about engines. Impala can create Iceberg tables, run `UPDATE`, `DELETE`, and `MERGE`, time travel, roll back, and expire snapshots. Hive and Spark in CDP work on the very same table, but you do not need them here.

An external Hive table is **a folder plus a definition in the Metastore**. Everything else — which files belong to the table, what changed, who may see half-finished work — is not tracked anywhere. A **table format** like Apache Iceberg adds that missing layer *inside the table folder*, as metadata files that every engine can read.

---

## Set up your tools

**Terminal.** Set your Kerberos identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`. `HIVE_EXT` is the default external folder of your database (one sub-folder per table). `ICE_META` is the folder of the Iceberg table you create in section 2:

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export HIVE_EXT="/warehouse/tablespace/external/hive/ws_${WORKSHOP_USER}.db"   # adjust if needed
export ICE_META="${HIVE_EXT}/ice_meter"
export IMPALA_OPTS="<impala-shell-options-from-handout>"   # only needed for check.sh at the end
```

**Hue.** Open **Editor → Impala** (URL from your handout) and paste the `sql` blocks of the lab unchanged.

- Run a statement with **Ctrl+Enter**. Hue runs the statement under the cursor; to run several statements one after another, select them first. Run the statements of a block **one at a time** when you want to look at each result.
- The lab SQL contains placeholders like `${ws_user}`. As soon as the editor contains one, Hue shows an **input field** below the editor. Type your `WORKSHOP_USER` into `ws_user`. Later sections use `${snap_first}`, `${snap_now}`, and `${snap_good}` the same way: you paste a snapshot ID from a query result into the field.
- Hue can also show HDFS: open **Files**, click the path at the top, and type a path such as `/warehouse/tablespace/external/hive/ws_<your_username>.db`. Every `hdfs dfs -ls` of the lab has this equivalent. The terminal is only needed for `hdfs dfs -cat`, `-cp`, `-count`, and `-rm`.

---

## 0. Orient — create the source tables

**Goal:** Create your database and the four small tables the lab works on.

In Hue (Impala editor). All statements use `IF NOT EXISTS`, so you can run the block again safely:

```sql
CREATE DATABASE IF NOT EXISTS ws_${ws_user};
USE ws_${ws_user};

CREATE EXTERNAL TABLE IF NOT EXISTS landisgyr_csv (
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

CREATE EXTERNAL TABLE IF NOT EXISTS landisgyr_changes (
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

CREATE EXTERNAL TABLE IF NOT EXISTS stations (
  station_id STRING,
  latitude DOUBLE,
  longitude DOUBLE,
  municipality STRING,
  district STRING,
  basemap_tile_hint STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS market_prices (
  timestamp_start STRING,
  timestamp_end STRING,
  market STRING,
  price_eur_mwh DOUBLE,
  price_ct_kwh DOUBLE,
  currency STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');
```

Each table is a folder below `HIVE_EXT`. Fill the folders in the terminal: three files from the shared workshop data, and a small correction file that you create yourself. It holds four corrected or new readings — `08:45` and `09:15` for `TS-101`, `09:00` and `09:15` for `TS-204` — and is used in sections 1 and 3. The commands overwrite existing files, so they are safe to repeat:

```bash
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_csv/"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv" "${HIVE_EXT}/stations/"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv" "${HIVE_EXT}/market_prices/"

cat > "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" <<'EOF'
timestamp,station_id,device_id,phase,active_power_kw,reactive_power_kvar,voltage_v,current_a,power_factor,frequency_hz,transformer_load_pct,quality_flag,event_code,comm_status
2026-01-15T08:45:00Z,TS-101,LG-TS-101-A,L1,203.9,38.8,229.0,318.0,0.980,49.99,68.9,OK,,ONLINE
2026-01-15T09:15:00Z,TS-101,LG-TS-101-A,L1,199.5,38.1,229.6,313.0,0.981,50.00,67.4,OK,,ONLINE
2026-01-15T09:00:00Z,TS-204,LG-TS-204-B,L2,111.0,21.2,231.9,171.5,0.981,50.00,40.1,OK,,MAINTENANCE
2026-01-15T09:15:00Z,TS-204,LG-TS-204-B,L2,108.9,20.9,232.0,169.0,0.981,50.00,39.5,OK,,MAINTENANCE
EOF
hdfs dfs -put -f "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" "${HIVE_EXT}/landisgyr_changes/"
hdfs dfs -ls -R "${HIVE_EXT}"
```

Impala caches the file list of a table, so tell it about the new files, then check the tables:

```sql
REFRESH landisgyr_csv;
REFRESH landisgyr_changes;
REFRESH stations;
REFRESH market_prices;

SELECT COUNT(*) FROM landisgyr_csv;
SELECT COUNT(*) FROM landisgyr_changes;
SELECT COUNT(*) FROM stations;
SELECT COUNT(*) FROM market_prices;
```

You should see 15, 4, 3, and 5 rows. `landisgyr_csv` holds three transformer stations with five 15-minute readings each.

---

## 1. Before Iceberg — idempotent loads by hand

**Goal:** Replace row-level `UPDATE`, `DELETE`, and `MERGE` on plain external tables with patterns that are safe to run twice: overwrite a partition, rewrite it, drop it. Then count what it cost.

On external tables `UPDATE` and `DELETE` fail: Impala cannot change files in place and there is no transaction layer for them. Jobs still have to correct and remove data, so engineers use the only unit that external tables offer: the partition. A job is **idempotent** if running it twice leaves the same result as running it once. Create a partitioned Parquet table and load it from the CSV table with **dynamic partitioning** (the partition values come from the last column of the `SELECT`):

```sql
CREATE EXTERNAL TABLE meter_part (
  ts_utc STRING,
  active_power_kw DOUBLE,
  reactive_power_kvar DOUBLE,
  voltage_v DOUBLE,
  current_a DOUBLE,
  transformer_load_pct DOUBLE,
  quality_flag STRING,
  event_code STRING,
  comm_status STRING
)
PARTITIONED BY (station_id STRING)
STORED AS PARQUET;

INSERT OVERWRITE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;

SELECT station_id, COUNT(*) FROM meter_part GROUP BY station_id;
```

Now simulate a retry in both flavours. The `INSERT INTO` duplicates, the `INSERT OVERWRITE` does not. Run the overwrite twice and compare:

```sql
INSERT INTO meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
SELECT COUNT(*) FROM meter_part;

INSERT OVERWRITE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
INSERT OVERWRITE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
SELECT COUNT(*) FROM meter_part;
```

You should see 30 rows after the `INSERT INTO` and 15 after the two overwrites. An overwrite replaces only the partitions that appear in the result of the `SELECT`. Look at the folders (terminal):

```bash
hdfs dfs -ls -R "${HIVE_EXT}/meter_part"
```

**Update by rewriting one partition.** Station `TS-101` had a voltage dip flagged `WARN`. Rewrite only that partition and change the flag with `CASE` — the other stations stay untouched:

```sql
INSERT OVERWRITE meter_part PARTITION (station_id = 'TS-101')
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct,
       CASE WHEN quality_flag = 'WARN' THEN 'REVIEWED' ELSE quality_flag END,
       event_code, comm_status
FROM meter_part
WHERE station_id = 'TS-101';

SELECT station_id, quality_flag, COUNT(*) FROM meter_part GROUP BY station_id, quality_flag;
```

**Delete by rewriting.** Remove the `HIGH_LOAD` events of `TS-305` by writing the partition back **without** them. `COALESCE` keeps rows whose `event_code` is empty or `NULL`:

```sql
INSERT OVERWRITE meter_part PARTITION (station_id = 'TS-305')
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status
FROM meter_part
WHERE station_id = 'TS-305' AND COALESCE(event_code, '') <> 'HIGH_LOAD';

SELECT station_id, COUNT(*) FROM meter_part GROUP BY station_id;
```

**Delete a whole partition.** Drop the partition of `TS-204`, then look at HDFS:

```sql
ALTER TABLE meter_part DROP PARTITION (station_id = 'TS-204');
SHOW PARTITIONS meter_part;
```

```bash
hdfs dfs -ls "${HIVE_EXT}/meter_part"
```

The partition disappears from queries, but the folder is still on HDFS because the table is external. Let Impala scan the table folder again:

```sql
ALTER TABLE meter_part RECOVER PARTITIONS;
SHOW PARTITIONS meter_part;
```

The partition comes back. To delete it for good, drop the metadata **and** remove the files, then recover:

```sql
ALTER TABLE meter_part DROP PARTITION (station_id = 'TS-204');
```

```bash
hdfs dfs -rm -r -skipTrash "${HIVE_EXT}/meter_part/station_id=TS-204"
```

```sql
ALTER TABLE meter_part RECOVER PARTITIONS;
SHOW PARTITIONS meter_part;
```

This time `TS-204` stays gone. Bring everything back by running the full overwrite from the source table once more — it rebuilds all partitions and fixes the changes from above:

```sql
INSERT OVERWRITE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
SELECT station_id, COUNT(*) FROM meter_part GROUP BY station_id;
```

**Merge by rewriting.** The correction file from section 0 (`landisgyr_changes`) has to be merged into the table. Take the two `TS-101` rows: one corrected reading at `08:45` and one new reading at `09:15`. A merge has two halves: keep the existing rows that were **not** corrected, and add all rows from the correction file. Write both back into the partition (safe to run twice):

```sql
INSERT OVERWRITE meter_part PARTITION (station_id = 'TS-101')
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status
FROM (
  SELECT cur.ts_utc, cur.active_power_kw, cur.reactive_power_kvar, cur.voltage_v, cur.current_a,
         cur.transformer_load_pct, cur.quality_flag, cur.event_code, cur.comm_status
  FROM meter_part cur
  LEFT JOIN landisgyr_changes chg
    ON chg.station_id = cur.station_id AND chg.ts_utc = cur.ts_utc
  WHERE cur.station_id = 'TS-101' AND chg.ts_utc IS NULL
  UNION ALL
  SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
         transformer_load_pct, quality_flag, event_code, comm_status
  FROM landisgyr_changes
  WHERE station_id = 'TS-101'
) merged;

SELECT ts_utc, quality_flag FROM meter_part WHERE station_id = 'TS-101' ORDER BY ts_utc;
```

You should see six readings for `TS-101`: the `08:45` flag is now `OK` and `09:15` is new.

Now count what this approach costs. Every change rewrote a **whole partition**, even if one row changed. There is no record of the old state: if the rewrite was wrong, the data is gone (and `-skipTrash` makes it final). A query that runs while a partition is being rewritten can see missing or half-written files. And all of it only works because **you** know the rules: overwrite instead of insert, recover after dropping, delete the files by hand.

**Check question:** Why is `INSERT OVERWRITE … PARTITION` safe to re-run while `INSERT INTO` is not? What happens to a station that is in the table but missing from the source when you run a dynamic overwrite?

---

## 2. A first Iceberg table — and the files behind it

**Goal:** Create an Iceberg table and find out what Iceberg stores on HDFS.

Create the table with the same columns as `landisgyr_csv`. `PARTITIONED BY SPEC (station_id)` is Iceberg's partitioning clause and `STORED AS ICEBERG` selects the table format. The property `format-version` = 2 is needed for row-level changes. Impala writes Parquet files and handles row-level changes as **merge-on-read** (you see what that means in section 3):

```sql
CREATE EXTERNAL TABLE ice_meter (
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
PARTITIONED BY SPEC (station_id)
STORED AS ICEBERG
TBLPROPERTIES ('format-version'='2');

INSERT INTO ice_meter SELECT * FROM landisgyr_csv;

SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
SHOW TBLPROPERTIES ice_meter;
DESCRIBE FORMATTED ice_meter;
```

In the output look for the table type, the `metadata_location` property, the partition transform (`station_id`, `IDENTITY`), and the `Location` below your `HIVE_EXT`. Unlike a partitioned external table, there is no `RECOVER PARTITIONS`: Iceberg tracks the partitions and files itself.

Now look at HDFS (terminal):

```bash
hdfs dfs -ls -R "${ICE_META}"
```

You should see two folders:

- `data/` — Parquet files in one sub-folder per station, written by your `INSERT`. These are normal Parquet files.
- `metadata/` — files that only Iceberg writes: `*.metadata.json` (the table definition), `snap-*.avro` (the **manifest list** of one snapshot) and `*-m0.avro` (the **manifest**, a list of data files with row counts and column statistics).

There are two `*.metadata.json` files: `00000-…` from `CREATE TABLE` and `00001-…` from the `INSERT`. Each change to the table writes a **new** metadata file and then switches the pointer `metadata_location` in the Metastore to it — that single switch is the commit. Read the newest one; it is plain JSON:

```bash
META=$(hdfs dfs -ls "${ICE_META}/metadata" | awk '/metadata.json/ {print $NF}' | sort | tail -1)
hdfs dfs -cat "${META}" | head -70
```

Find `format-version`, the `schemas` (your columns), the `partition-specs`, and the `snapshots` list with its `manifest-list` and `summary` (`added-data-files`, `added-records`). The Avro files are binary; read their content with SQL instead. The `files` metadata table lists the data files that the current snapshot consists of:

```sql
SELECT content, file_path, record_count, file_size_in_bytes
FROM ws_${ws_user}.ice_meter.files;
```

`content = 0` means a data file. Compare the paths with your `hdfs dfs -ls -R` output. `SHOW FILES IN ice_meter;` shows the same list.

**Check question:** Which file does `metadata_location` point to, and what does a reader do with it? Which file would you have to change to make an old row disappear — and why can nobody do that in place?

---

## 3. UPDATE, DELETE, MERGE — and what happens on HDFS

**Goal:** Do the changes of section 1 with plain SQL and watch the files.

The `UPDATE` and `DELETE` that fail on external tables now work. `TS-204` is commissioned at `08:30`, so its first two readings are test data: mark the station as under maintenance and delete the early readings.

```sql
UPDATE ice_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM ice_meter WHERE station_id = 'TS-305' AND event_code = 'HIGH_LOAD';
UPDATE ice_meter SET comm_status = 'MAINTENANCE' WHERE station_id = 'TS-204';
DELETE FROM ice_meter WHERE station_id = 'TS-204' AND ts_utc < '2026-01-15T08:30:00Z';

SELECT station_id, quality_flag, comm_status, COUNT(*)
FROM ice_meter GROUP BY station_id, quality_flag, comm_status ORDER BY station_id;
```

List the files again (terminal) and compare with section 2:

```bash
hdfs dfs -ls -R "${ICE_META}/data"
hdfs dfs -ls "${ICE_META}/metadata"
```

The old data files are **still there**, unchanged. With merge-on-read Iceberg writes small **delete files** next to them (Parquet files that list the file path and row position of every deleted row) and, for an `UPDATE`, a delete file plus a new data file with the new row versions. Readers combine data and delete files. Ask the `files` table which is which:

```sql
SELECT content, file_path, record_count FROM ws_${ws_user}.ice_meter.files ORDER BY content, file_path;
```

`content = 1` means a **position delete** file. Every statement also added a `*.metadata.json` file and a snapshot.

Now a `MERGE`. It reads the correction file through `landisgyr_changes` and handles all four rows at once: it updates the two readings that exist (`TS-101` at `08:45`, `TS-204` at `09:00`) and inserts the two new ones (`09:15` of both stations). `UPDATE SET *` and `INSERT *` map the columns of the source by name:

```sql
MERGE INTO ice_meter AS t
USING landisgyr_changes AS s
ON t.station_id = s.station_id AND t.ts_utc = s.ts_utc
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
SELECT ts_utc, quality_flag FROM ice_meter WHERE station_id = 'TS-101' ORDER BY ts_utc;
```

You should see 6 readings for `TS-101`, 4 for `TS-204`, and 3 for `TS-305` (13 rows), with `08:45` of `TS-101` now `OK`. Run the `MERGE` a second time and count again: still 13. A `MERGE` on a unique key is idempotent — no `meter_part` tricks.

Look at the snapshots Impala has created so far. Each statement is one row:

```sql
DESCRIBE HISTORY ice_meter;
SELECT committed_at, snapshot_id, operation FROM ws_${ws_user}.ice_meter.snapshots ORDER BY committed_at;
```

Compare the effort with section 1: five row-level changes, five statements, no partition rewriting, no manual file handling, and a list of everything that happened.

**Check question:** On a Hive managed (ACID) table, `UPDATE` and `DELETE` write `delta_` and `delete_delta_` folders. What is the equivalent here, and who cleans it up?

---

## 4. History and time travel

**Goal:** Read the table as it was before any of the changes.

Each commit created a **snapshot**: a complete, consistent state of the table. Old snapshots stay readable until you expire them (section 7). Get the ID of the first snapshot — your first `INSERT`, the table as you loaded it — and paste it into the `snap_first` field of Hue:

```sql
SELECT snapshot_id, committed_at FROM ws_${ws_user}.ice_meter.snapshots ORDER BY committed_at LIMIT 1;
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

You can also travel by **time** instead of by ID: `FOR SYSTEM_TIME AS OF '<timestamp>'` (UTC) or `FOR SYSTEM_TIME AS OF now() - INTERVAL 30 MINUTES`.

`history` shows the lineage of the snapshots. The column `is_current_ancestor` is `true` for every snapshot that leads to the current table — it becomes interesting after a rollback in section 7:

```sql
SELECT * FROM ws_${ws_user}.ice_meter.history ORDER BY made_current_at;
```

What this replaces: with plain external tables, "what did the table look like at 09:00?" is only answerable if somebody kept a copy. And because snapshots are read-only, an auditor's query on `snap_first` gives the same result next week as today, no matter what the pipelines change in the meantime.

**Check question:** What does the snapshot list tell you that a copy of the table could not — and what does keeping the history cost?

---

## 5. Snapshot isolation — readers and files

**Goal:** Show that a change never touches the files an earlier snapshot refers to.

Take the current snapshot as a reference point and paste its ID into the `snap_now` field:

```sql
SELECT snapshot_id, committed_at FROM ws_${ws_user}.ice_meter.snapshots ORDER BY committed_at DESC LIMIT 1;
```

```bash
hdfs dfs -ls "${ICE_META}/data/station_id=TS-101"
```

Change a value for the whole station:

```sql
UPDATE ice_meter SET frequency_hz = 50.50 WHERE station_id = 'TS-101';
```

The reader pinned to the old snapshot and the reader of the current table see different values at the same moment:

```sql
SELECT frequency_hz, COUNT(*) AS n FROM ice_meter FOR SYSTEM_VERSION AS OF ${snap_now}
WHERE station_id = 'TS-101' GROUP BY frequency_hz ORDER BY frequency_hz;
SELECT frequency_hz, COUNT(*) AS n FROM ice_meter
WHERE station_id = 'TS-101' GROUP BY frequency_hz ORDER BY frequency_hz;
```

```bash
hdfs dfs -ls "${ICE_META}/data/station_id=TS-101"
```

The listing now has **more** files than before and none of the old ones was modified or removed. That is **snapshot isolation**:

- A query reads the table metadata **once**, at the start, and then reads exactly the files of that snapshot. A change that is committed while the query runs creates new files and a new snapshot; the running query never sees it.
- A commit is one atomic step (the metadata pointer in the Metastore). Readers see the table either before or after a change, never half of it. Compare that with `INSERT OVERWRITE` in section 1, where a reader could meet a partition that was just emptied.
- Writers do not block readers. Two writers that change the same table at the same time use **optimistic concurrency**: each prepares its files, then tries to commit against the snapshot it started from. If another commit came first, one writer retries or fails — it never silently overwrites the other. Your instructor shows this live.

The price: old files stay on HDFS until you expire the snapshots (section 7).

**Check question:** A report job runs for 20 minutes while the pipeline commits every 5 minutes. Which data does the report see — and what must you keep so that a long-running report does not fail?

---

## 6. Joins on Iceberg tables

**Goal:** Use the table in joins: semi and anti joins, outer joins, range joins, and a diff between two snapshots. The queries run on `ice_meter` and the small tables from section 0: `stations` and `market_prices`.

**Semi and anti joins — "does a match exist?"** A semi join returns each row of the left table once if it has a match, and never multiplies rows. Which stations had a reading above 80 % transformer load? Which stations never went above 60 %?

```sql
SELECT s.station_id, s.district
FROM stations s
LEFT SEMI JOIN ice_meter m
  ON s.station_id = m.station_id AND m.transformer_load_pct > 80;

SELECT s.station_id, s.district
FROM stations s
LEFT JOIN (SELECT DISTINCT station_id FROM ice_meter WHERE transformer_load_pct > 60) busy
  ON s.station_id = busy.station_id
WHERE busy.station_id IS NULL;

SELECT s.station_id
FROM stations s
WHERE NOT EXISTS (
  SELECT 1 FROM ice_meter m WHERE m.station_id = s.station_id AND m.transformer_load_pct > 60
);
```

The second and third statement are two spellings of an **anti join** (rows without a match): `LEFT JOIN … IS NULL`, and `NOT EXISTS`. The semi join returns `TS-305`; both anti joins return `TS-204`. Use whichever reads better.

**Full outer join — "show me everything from both sides".** Hourly consumption of all stations against the hourly price. Hours with a price but no meter data show `NULL` for `kwh`:

```sql
WITH hourly AS (
  SELECT SUBSTR(ts_utc, 1, 13) AS hr, ROUND(SUM(active_power_kw * 0.25), 1) AS kwh
  FROM ice_meter
  GROUP BY SUBSTR(ts_utc, 1, 13)
), prices AS (
  SELECT SUBSTR(timestamp_start, 1, 13) AS hr, price_ct_kwh FROM market_prices
)
SELECT COALESCE(h.hr, p.hr) AS hr, h.kwh, p.price_ct_kwh,
       ROUND(h.kwh * p.price_ct_kwh / 100, 2) AS cost_eur
FROM hourly h
FULL OUTER JOIN prices p ON h.hr = p.hr
ORDER BY hr;
```

The `0.25` turns a 15-minute average power in kW into kWh. `COALESCE` picks the key from whichever side has it.

**Range join — "which interval does this reading fall into?"** Instead of cutting strings to the hour, join each reading to the price interval that contains it. The condition is a range, not an equality; the extra equality on the date keeps the engine from comparing every reading with every price:

```sql
SELECT m.station_id, m.ts_utc, m.active_power_kw, p.price_ct_kwh
FROM ice_meter m
JOIN market_prices p
  ON SUBSTR(m.ts_utc, 1, 10) = SUBSTR(p.timestamp_start, 1, 10)
 AND m.ts_utc >= p.timestamp_start
 AND m.ts_utc <  p.timestamp_end
ORDER BY m.station_id, m.ts_utc;
```

You should get exactly one row per reading (13). If you get more, the intervals overlap; fewer, there are gaps. Always compare the row count with the left table.

**Join two snapshots — what changed?** Only a table format lets you do this: a `FULL OUTER JOIN` of the table as of `snap_first` with the table now, on the key of a reading. Everything on only one side was deleted or inserted, and a difference in values means a change:

```sql
WITH at_first AS (SELECT * FROM ice_meter FOR SYSTEM_VERSION AS OF ${snap_first}),
     at_now AS (SELECT * FROM ice_meter)
SELECT COALESCE(c.station_id, o.station_id) AS station_id,
       COALESCE(c.ts_utc, o.ts_utc) AS ts_utc,
       CASE WHEN o.ts_utc IS NULL THEN 'inserted'
            WHEN c.ts_utc IS NULL THEN 'deleted'
            WHEN o.quality_flag <> c.quality_flag OR o.comm_status <> c.comm_status
                 OR o.active_power_kw <> c.active_power_kw OR o.frequency_hz <> c.frequency_hz THEN 'changed'
            ELSE 'unchanged' END AS change
FROM at_first o
FULL OUTER JOIN at_now c ON o.station_id = c.station_id AND o.ts_utc = c.ts_utc
ORDER BY station_id, ts_utc;
```

You should see 17 rows: 3 unchanged (`TS-305`), 8 changed (the five remaining original readings of `TS-101` after the frequency update in section 5, and the three remaining original readings of `TS-204`, now in maintenance), 4 deleted (two `HIGH_LOAD` readings of `TS-305`, two early readings of `TS-204`), and 2 inserted (the `09:15` readings). It is a complete audit trail of sections 3 and 5 from one query. With external tables you would need a copy of the old data for this.

**Check question:** The range join returned 13 rows. After somebody loads a second `market_prices` file for the same day (overlapping hours), what happens to the count — and how do you notice?

---

## 7. Undo and clean up — rollback and expire snapshots

**Goal:** Recover from a wrong statement, then remove history you no longer need and see the files go.

First remember the good state: get the ID of the current snapshot and paste it into the `snap_good` field of Hue:

```sql
SELECT snapshot_id, committed_at FROM ws_${ws_user}.ice_meter.snapshots ORDER BY committed_at DESC LIMIT 1;
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
SELECT snapshot_id, parent_id, is_current_ancestor FROM ws_${ws_user}.ice_meter.history ORDER BY made_current_at;
```

The count is 13 again. In the history the wrong `DELETE` is still listed, but with `is_current_ancestor = false`: it is not part of the table's lineage any more. Compare with section 1, where the same mistake on an external table would have been permanent.

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

The `metadata` folder keeps its old `*.metadata.json` files unless the table property `write.metadata.delete-after-commit.enabled` is set.

Expiring is a decision about **how long you want to keep history** — for audits, for rollbacks, for GDPR deletes (an expired snapshot no longer contains the deleted person's data). A production table gets a schedule: keep the last 30 days, expire the rest.

**Check question:** A "right to be forgotten" request means a customer's rows must disappear from the table **and** from its history. Which two steps are needed?

---

## 8. Where Iceberg fits

**Goal:** Decide where Iceberg belongs in the pilot.

What you saw in the lab: an Iceberg table is a folder with `data/` and `metadata/`, and a pointer in the Metastore. `UPDATE`, `DELETE`, and `MERGE` are plain SQL and write new files instead of changing old ones; snapshot list, time travel, rollback, and expiry come with the format. For the section 1 patterns there is nothing left to do by hand: also deleting a whole station is a plain `DELETE`. Hive and Spark work on the same table — nothing is exported or copied — which is why the format is a good basis for a shared lakehouse.

When Iceberg is **not** the answer: raw landing zones where files arrive from outside (keep them as external tables), and tiny reference tables nobody changes.

**Check question:** Which tables of your pilot (smart-meter readings, market prices, weather, station master data) would you make Iceberg tables first, and which stay external CSV or Parquet?

---

## Stretch (optional)

- **Time travel by time:** `SELECT COUNT(*) FROM ice_meter FOR SYSTEM_TIME AS OF now() - INTERVAL 30 MINUTES;` — it works as soon as the snapshot you want is older than that and has not been expired.
- **Migrate a table in place:** `CREATE TABLE meter_parquet STORED AS PARQUET AS SELECT * FROM landisgyr_csv;`, then `ALTER TABLE meter_parquet CONVERT TO ICEBERG;`. The table becomes an Iceberg table without rewriting the data files. Look at the folder of `meter_parquet` on HDFS afterwards: a new `metadata` folder next to the old files. The row count stays 15.
- **Partition evolution:** `ALTER TABLE <t> SET PARTITION SPEC (HOUR(ts))` needs a timestamp column; the lab table has strings. Try it on a new Iceberg table created with `CAST(REPLACE(SUBSTR(ts_utc, 1, 19), 'T', ' ') AS TIMESTAMP)` as `ts`: old data stays in the old layout, new data uses the new one, and queries work on both.
- **Compact small files:** every `INSERT` adds files. `OPTIMIZE TABLE ice_meter;` rewrites them into fewer, larger files (if your Runtime release supports it). List `${ICE_META}/data` before and after. After a compaction the old files stay until you expire the snapshots.
- **Drop an Iceberg table:** create a throw-away table (`CREATE EXTERNAL TABLE t (i INT) STORED AS ICEBERG` and an `INSERT`), check `SHOW TBLPROPERTIES t`, drop it and look at its folder. Do the files stay (external) or go (`external.table.purge`)? Compare with what `DROP TABLE` did to the external CSV table in section 0.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket, `IMPALA_OPTS`, and the tables you created):

```bash
./07-lakehouse-iceberg/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
