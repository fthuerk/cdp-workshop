# Lakehouse hands-on lab (Iceberg)

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. The lab builds its own database and source tables in section 0 (a few statements; nothing from other modules is required). You work in up to four terminals on the edge node:

| Terminal | Used for | From section |
|----------|----------|--------------|
| 1 | `beeline` (Hive SQL) | 0 |
| 2 | `hdfs` commands and small shell helpers | 0 |
| 3 | `impala-shell` | 4 |
| 4 | `spark3-shell` (Spark SQL) | 5 |

Set your Kerberos identity and paths once in **every** terminal. `WORKSHOP_USER` is the short name you use with `kinit`. `HIVE_EXT` is the default external folder of your database (Hive creates one sub-folder per table in it). `ICE_META` is the folder of the Iceberg table you create in section 2. `HS2_URL` is the HiveServer2 JDBC URL and `IMPALA_OPTS` the `impala-shell` options, both from your handout.

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export HIVE_EXT="/warehouse/tablespace/external/hive/ws_${WORKSHOP_USER}.db"   # adjust if needed
export ICE_META="${HIVE_EXT}/ice_meter"
export HS2_URL="<jdbc-url-from-your-handout>"
export IMPALA_OPTS="<impala-shell-options-from-handout>"   # e.g. -i impala-host:21050
```

An external Hive table is **a folder plus a definition in the Metastore**. Everything else — which files belong to the table, what changed, who may see half-finished work — is not tracked anywhere. A **table format** like Apache Iceberg adds that missing layer *inside the table folder*, as metadata files that every engine can read. Hive, Impala, and Spark in CDP all work on the same Iceberg table; nothing is copied between them.

---

## Optional — Hue

Sections 1–3 and the SQL blocks of section 8 (all except the snapshot diff) also run in **Hue → Editor → Hive**, and section 4 in **Editor → Impala**; see the Hue notes in the [Hive lab](../../04-basics-hive/lab/lab_basics_hive.md#optional--use-hue-instead-of-beeline-and-hdfs). The shell helpers with `${SNAP_FIRST}`, `${SNAP_NOW}`, and `${SNAP_GOOD}` (sections 6–9), `spark3-shell`, and the `hdfs` commands need a terminal (the Hue File Browser works for listing folders).

---

## 0. Orient — connect and create the source tables

**Goal:** Start Beeline and create your database and the four small tables the lab works on.

Terminal 1:

```bash
beeline -u "${HS2_URL}" --hivevar ws_user="${WORKSHOP_USER}"
```

The `--hivevar` option defines `${ws_user}` for the SQL (in Hue it becomes an input field). All statements use `IF NOT EXISTS`, so you can run the block again safely:

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

CREATE EXTERNAL TABLE IF NOT EXISTS landisgyr_changes LIKE landisgyr_csv;

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

Each table is a folder below `HIVE_EXT` (Hive created them). Fill the folders from terminal 2: three files from the shared workshop data, and a small correction file for `TS-101` — one corrected reading (`08:45`) and one new reading (`09:15`) — that you create yourself. The commands overwrite existing files, so they are safe to repeat:

```bash
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_csv/"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv" "${HIVE_EXT}/stations/"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv" "${HIVE_EXT}/market_prices/"

cat > "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" <<'EOF'
timestamp,station_id,device_id,phase,active_power_kw,reactive_power_kvar,voltage_v,current_a,power_factor,frequency_hz,transformer_load_pct,quality_flag,event_code,comm_status
2026-01-15T08:45:00Z,TS-101,LG-TS-101-A,L1,203.9,38.8,229.0,318.0,0.980,49.99,68.9,OK,,ONLINE
2026-01-15T09:15:00Z,TS-101,LG-TS-101-A,L1,199.5,38.1,229.6,313.0,0.981,50.00,67.4,OK,,ONLINE
EOF
hdfs dfs -put -f "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" "${HIVE_EXT}/landisgyr_changes/"
```

Check the tables:

```sql
SELECT COUNT(*) FROM landisgyr_csv;
SELECT COUNT(*) FROM landisgyr_changes;
SELECT COUNT(*) FROM stations;
SELECT COUNT(*) FROM market_prices;
```

You should see 15, 2, 3, and 5 rows. `landisgyr_csv` holds three transformer stations with five 15-minute readings each.

What each engine can do with Iceberg tables in CDP 7.3.2 — the sections below try every cell of this table:

| | Hive | Impala | Spark 3 |
|---|---|---|---|
| Create an Iceberg table | `STORED BY ICEBERG` | `STORED BY ICEBERG` | `USING iceberg` |
| `INSERT` / CTAS | yes | yes | yes |
| `UPDATE`, `DELETE`, `MERGE` | yes | yes (needs Parquet; format v2) | yes |
| How rows are changed | copy-on-write or merge-on-read | merge-on-read only | copy-on-write or merge-on-read |
| Snapshot list | `<table>.snapshots` | `DESCRIBE HISTORY` | `<table>.snapshots` |
| Time travel | `FOR SYSTEM_TIME / SYSTEM_VERSION AS OF` | same | `TIMESTAMP / VERSION AS OF` |
| Roll back | `ALTER TABLE … EXECUTE ROLLBACK(…)` | same | `CALL system.rollback_to_snapshot(…)` |
| Expire old snapshots | `ALTER TABLE … EXECUTE EXPIRE_SNAPSHOTS(…)` | same | `CALL system.expire_snapshots(…)` |

Impala `UPDATE` and `MERGE` need Cloudera Runtime 7.3.1.500 or later. Spark needs the Iceberg SQL extensions for `UPDATE`, `MERGE`, and `CALL` (you add them when you start the shell).

---

## 1. Before Iceberg — idempotent loads by hand

**Goal:** Replace row-level `UPDATE`, `DELETE`, and `MERGE` on plain external tables with patterns that are safe to run twice: overwrite a partition, rewrite it, drop it. Then count what it cost.

On external tables `UPDATE` and `DELETE` fail: Hive cannot change files in place and has no transaction layer for them. Jobs still have to correct and remove data, so engineers use the only unit that external tables offer: the partition. A job is **idempotent** if running it twice leaves the same result as running it once. Create a partitioned ORC table and load it from the CSV table with **dynamic partitioning** (Hive takes the partition values from the last column of the `SELECT`):

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
STORED AS ORC;

SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT OVERWRITE TABLE meter_part PARTITION (station_id)
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

INSERT OVERWRITE TABLE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
INSERT OVERWRITE TABLE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
SELECT COUNT(*) FROM meter_part;
```

You should see 30 rows after the `INSERT INTO` and 15 after the two overwrites. An overwrite replaces only the partitions that appear in the result of the `SELECT`.

**Update by rewriting one partition.** Station `TS-101` had a voltage dip flagged `WARN`. Rewrite only that partition and change the flag with `CASE` — the other stations stay untouched:

```sql
INSERT OVERWRITE TABLE meter_part PARTITION (station_id = 'TS-101')
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
INSERT OVERWRITE TABLE meter_part PARTITION (station_id = 'TS-305')
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status
FROM meter_part
WHERE station_id = 'TS-305' AND COALESCE(event_code, '') <> 'HIGH_LOAD';

SELECT station_id, COUNT(*) FROM meter_part GROUP BY station_id;
```

**Delete a whole partition.** Drop the partition of `TS-204`, then look at HDFS (terminal 2):

```sql
ALTER TABLE meter_part DROP PARTITION (station_id = 'TS-204');
SHOW PARTITIONS meter_part;
```

```bash
hdfs dfs -ls "${HIVE_EXT}/meter_part"
```

The partition disappears from queries, but the folder is still on HDFS because the table is external. Let Hive scan the folder again:

```sql
MSCK REPAIR TABLE meter_part;
SHOW PARTITIONS meter_part;
```

The partition comes back. To delete it for good, drop the metadata **and** remove the files, then repair:

```sql
ALTER TABLE meter_part DROP PARTITION (station_id = 'TS-204');
```

```bash
hdfs dfs -rm -r -skipTrash "${HIVE_EXT}/meter_part/station_id=TS-204"
```

```sql
MSCK REPAIR TABLE meter_part;
SHOW PARTITIONS meter_part;
```

This time `TS-204` stays gone. Bring everything back by running the full overwrite from the source table once more — it rebuilds all partitions and fixes the changes from above:

```sql
INSERT OVERWRITE TABLE meter_part PARTITION (station_id)
SELECT ts_utc, active_power_kw, reactive_power_kvar, voltage_v, current_a,
       transformer_load_pct, quality_flag, event_code, comm_status, station_id
FROM landisgyr_csv;
SELECT station_id, COUNT(*) FROM meter_part GROUP BY station_id;
```

**Merge by rewriting.** The correction file from section 0 (`landisgyr_changes`: one corrected reading at `08:45` and one new reading at `09:15` for `TS-101`) has to be merged into the table. A merge has two halves: keep the existing rows that were **not** corrected, and add all rows from the correction file. Write both back into the partition (safe to run twice):

```sql
INSERT OVERWRITE TABLE meter_part PARTITION (station_id = 'TS-101')
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

Now count what this approach costs. Every change rewrote a **whole partition**, even if one row changed. There is no record of the old state: if the rewrite was wrong, the data is gone (and `-skipTrash` makes it final). A query that runs while a partition is being rewritten can see missing or half-written files. And all of it only works because **you** know the rules: overwrite instead of insert, repair after dropping, delete the files by hand.

**Check question:** Why is `INSERT OVERWRITE … PARTITION` safe to re-run while `INSERT INTO` is not? What happens to a station that is in the table but missing from the source when you run a dynamic overwrite?

---

## 2. A first Iceberg table — and the files behind it

**Goal:** Create an Iceberg table from Hive and find out what Iceberg stores on HDFS.

Create the table with the same columns as `landisgyr_csv`. `PARTITIONED BY SPEC (station_id)` is Iceberg's partitioning clause, `STORED BY ICEBERG` selects the table format, and the properties choose format version 2 (needed for row-level changes), Parquet files, and **merge-on-read** (you see what that means in section 3):

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
STORED BY ICEBERG
STORED AS PARQUET
TBLPROPERTIES (
  'format-version'='2',
  'write.format.default'='parquet',
  'write.delete.format.default'='parquet',
  'write.delete.mode'='merge-on-read',
  'write.update.mode'='merge-on-read',
  'write.merge.mode'='merge-on-read'
);

INSERT INTO ice_meter SELECT * FROM landisgyr_csv;

SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
DESCRIBE FORMATTED ice_meter;
```

In the `DESCRIBE` output look for the table type, the `metadata_location` property, the partition transform (`station_id`, `IDENTITY`), and the `Location` below your `HIVE_EXT`. Unlike a partitioned external table, there is no `ADD PARTITION` and no `MSCK REPAIR`: Iceberg tracks the partitions and files itself.

Now look at HDFS (terminal 2):

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

`content = 0` means a data file. Compare the paths with your `hdfs dfs -ls -R` output.

**Check question:** Which file would you have to change to make an old row disappear — and why can nobody do that in place? (Hint: look at what the Metastore knows and what the metadata file knows.)

---

## 3. UPDATE, DELETE, MERGE with Hive — and what happens on HDFS

**Goal:** Do the changes of section 1 with plain SQL and watch the files.

Terminal 1. The `UPDATE` and `DELETE` that fail on external tables now work:

```sql
UPDATE ice_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM ice_meter WHERE station_id = 'TS-305' AND event_code = 'HIGH_LOAD';

SELECT station_id, quality_flag, COUNT(*) FROM ice_meter GROUP BY station_id, quality_flag ORDER BY station_id;
```

Terminal 2: list the files again and compare with section 2.

```bash
hdfs dfs -ls -R "${ICE_META}/data"
hdfs dfs -ls "${ICE_META}/metadata"
```

The old data files are **still there**, unchanged. With merge-on-read Iceberg writes small **delete files** next to them (Parquet files that list the file path and row position of every deleted row) and, for an `UPDATE`, a delete file plus a new data file with the new row versions. Readers combine data and delete files. Ask the `files` table which is which:

```sql
SELECT content, file_path, record_count FROM ws_${ws_user}.ice_meter.files ORDER BY content, file_path;
```

`content = 1` means a **position delete** file. Every statement also added a `*.metadata.json` file and a snapshot.

Now a `MERGE` (the same statement works on Hive managed ACID tables). It reads the correction file through `landisgyr_changes`:

```sql
MERGE INTO ice_meter AS t
USING landisgyr_changes AS s
ON t.station_id = s.station_id AND t.ts_utc = s.ts_utc
WHEN MATCHED THEN UPDATE SET
  active_power_kw = s.active_power_kw,
  reactive_power_kvar = s.reactive_power_kvar,
  voltage_v = s.voltage_v,
  current_a = s.current_a,
  power_factor = s.power_factor,
  transformer_load_pct = s.transformer_load_pct,
  quality_flag = s.quality_flag,
  event_code = s.event_code
WHEN NOT MATCHED THEN INSERT VALUES (
  s.ts_utc, s.station_id, s.device_id, s.phase, s.active_power_kw, s.reactive_power_kvar,
  s.voltage_v, s.current_a, s.power_factor, s.frequency_hz, s.transformer_load_pct,
  s.quality_flag, s.event_code, s.comm_status
);

SELECT ts_utc, quality_flag FROM ice_meter WHERE station_id = 'TS-101' ORDER BY ts_utc;
```

You should see six readings for `TS-101`, `08:45` now `OK`. Run the `MERGE` a second time and count the rows of `TS-101`: still six. A `MERGE` on a unique key is idempotent — no `meter_part` tricks.

Look at the snapshots Hive has created so far. Each statement is one row:

```sql
SELECT committed_at, snapshot_id, operation FROM ws_${ws_user}.ice_meter.snapshots ORDER BY committed_at;
```

Compare the effort with section 1: three row-level changes, three statements, no partition rewriting, no manual file handling, and a list of everything that happened.

**Check question:** On a Hive managed (ACID) table, `UPDATE` and `DELETE` write `delta_` and `delete_delta_` folders. What is the equivalent here, and who cleans it up?

---

## 4. The same table in Impala

**Goal:** Change the table from a second engine without any export or copy.

Terminal 3:

```bash
impala-shell ${IMPALA_OPTS} -d ws_${WORKSHOP_USER}
```

Impala caches table metadata. A table that Hive has just created and changed is new to it, so load the metadata first:

```sql
INVALIDATE METADATA ice_meter;
SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
SHOW FILES IN ice_meter;
```

The counts are the result of the Hive statements from section 3, and `SHOW FILES` lists the same data and delete files that you saw on HDFS. `TS-204` is commissioned at `08:30`, so its first two readings are test data. Mark the station as under maintenance and delete the early readings:

```sql
UPDATE ice_meter SET comm_status = 'MAINTENANCE' WHERE station_id = 'TS-204';
DELETE FROM ice_meter WHERE station_id = 'TS-204' AND ts_utc < '2026-01-15T08:30:00Z';

SELECT station_id, ts_utc, comm_status FROM ice_meter WHERE station_id = 'TS-204' ORDER BY ts_utc;
DESCRIBE HISTORY ice_meter;
```

`DESCRIBE HISTORY` is Impala's snapshot list. Your Impala statements show up in the same list as the Hive statements — it is one table with one history. Impala can only write **merge-on-read** (delete files), and it needs Parquet for the data and delete files it writes: that is why the table properties of section 2 name Parquet for both.

Back in terminal 1 (Hive), the changes are visible immediately, because Hive reads the current metadata pointer for every query:

```sql
SELECT station_id, COUNT(*) FROM ice_meter GROUP BY station_id ORDER BY station_id;
```

Impala has `MERGE` too, with the same syntax as in section 3 (and shortcuts such as `UPDATE SET *` and `INSERT *`). You do not need to repeat it here.

**Check question:** Which files on HDFS did the Impala `DELETE` create, and which did it remove?

---

## 5. The same table in Spark

**Goal:** Use the table from a third engine, with a `MERGE` that updates one reading and inserts another.

Terminal 4. Start Spark with the Iceberg SQL extensions (they add `UPDATE`, `MERGE`, and `CALL` to Spark SQL). The Iceberg libraries and the Metastore catalog are already part of Spark in CDP:

```bash
spark3-shell --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
```

If your handout names the Spark 3 client differently (for example `spark-shell`), use that command. In the Scala shell:

```scala
val db = "ws_" + sys.env("WORKSHOP_USER")
spark.sql(s"USE $db")
spark.sql("SELECT station_id, COUNT(*) AS n FROM ice_meter GROUP BY station_id ORDER BY station_id").show(false)
```

You should see the effect of the Hive and Impala statements. The operator sends a corrected reading for `TS-204` at `09:00` and a new one at `09:15`. `UPDATE SET *` and `INSERT *` map the columns of the source by name:

```scala
spark.sql("""
MERGE INTO ice_meter t
USING (
  SELECT '2026-01-15T09:00:00Z' AS ts_utc, 'TS-204' AS station_id, 'LG-TS-204-B' AS device_id, 'L2' AS phase,
         111.0D AS active_power_kw, 21.2D AS reactive_power_kvar, 231.9D AS voltage_v, 171.5D AS current_a,
         0.981D AS power_factor, 50.00D AS frequency_hz, 40.1D AS transformer_load_pct,
         'OK' AS quality_flag, '' AS event_code, 'MAINTENANCE' AS comm_status
  UNION ALL
  SELECT '2026-01-15T09:15:00Z', 'TS-204', 'LG-TS-204-B', 'L2',
         108.9D, 20.9D, 232.0D, 169.0D, 0.981D, 50.00D, 39.5D, 'OK', '', 'MAINTENANCE'
) s
ON t.station_id = s.station_id AND t.ts_utc = s.ts_utc
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
""")

spark.sql("SELECT station_id, COUNT(*) AS n FROM ice_meter GROUP BY station_id ORDER BY station_id").show(false)
```

Spark can also list the snapshots. With the Iceberg session catalog, the metadata table needs the fully qualified name, including `spark_catalog`:

```scala
spark.sql(s"SELECT committed_at, snapshot_id, operation FROM spark_catalog.$db.ice_meter.snapshots ORDER BY committed_at").show(false)
```

Leave the Spark shell open for section 6. Impala needs to be told about commits that other engines made if you want to read them there: run `REFRESH ice_meter;` in terminal 3 before you query again. Check in Hive that the table now has 13 rows: 6 for `TS-101`, 4 for `TS-204`, 3 for `TS-305`.

Which engine for which statement? In section 10 you compare the three side by side. Remember for now: all three wrote to the **same** table, the table has one linear history, and no file was converted or exported.

**Check question:** Why can Spark, Impala, and Hive write to the same table without locking each other out — what do they have to agree on?

---

## 6. History and time travel

**Goal:** Read the table as it was before any of the changes, in all three engines.

Each commit created a **snapshot**: a complete, consistent state of the table. Old snapshots stay readable until you expire them (section 9). Work in terminal 2 and define two helpers that run one statement in Hive or Impala from bash, so that `bash` can pass snapshot IDs into the SQL:

```bash
hql() { beeline -u "${HS2_URL}" --silent=true -e "USE ws_${WORKSHOP_USER}; $1"; }
imp() { impala-shell ${IMPALA_OPTS} -d "ws_${WORKSHOP_USER}" -q "$1"; }

export SNAP_FIRST=$(beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
  -e "SELECT snapshot_id FROM ws_${WORKSHOP_USER}.ice_meter.snapshots ORDER BY committed_at LIMIT 1" | tail -1)
echo "${SNAP_FIRST}"
```

`SNAP_FIRST` is the snapshot of your first `INSERT` — the table as you loaded it. In Hive, ask for the table as of that snapshot, and for the table now:

```bash
hql "SELECT station_id, COUNT(*) AS n FROM ice_meter FOR SYSTEM_VERSION AS OF ${SNAP_FIRST} GROUP BY station_id ORDER BY station_id"
hql "SELECT station_id, COUNT(*) AS n FROM ice_meter GROUP BY station_id ORDER BY station_id"
```

You should see 5 / 5 / 5 rows for the first snapshot and 6 / 4 / 3 now. See the old and the new state of one reading:

```bash
hql "SELECT ts_utc, quality_flag, comm_status FROM ice_meter FOR SYSTEM_VERSION AS OF ${SNAP_FIRST} WHERE station_id = 'TS-101' AND ts_utc = '2026-01-15T08:45:00Z'"
hql "SELECT ts_utc, quality_flag, comm_status FROM ice_meter WHERE station_id = 'TS-101' AND ts_utc = '2026-01-15T08:45:00Z'"
```

The same query in **Impala** (note `REFRESH` first, to pick up the Spark commit) and in **Spark** (terminal 4, where `first` is the oldest snapshot ID read from the table itself):

```bash
imp "REFRESH ice_meter"
imp "SELECT station_id, COUNT(*) AS n FROM ice_meter FOR SYSTEM_VERSION AS OF ${SNAP_FIRST} GROUP BY station_id ORDER BY station_id"
```

```scala
val first = spark.sql(s"SELECT snapshot_id FROM spark_catalog.$db.ice_meter.snapshots ORDER BY committed_at LIMIT 1").first.getLong(0)
spark.sql(s"SELECT station_id, COUNT(*) AS n FROM ice_meter VERSION AS OF $first GROUP BY station_id ORDER BY station_id").show(false)
```

Three engines, same answer. By **time** instead of by ID: `FOR SYSTEM_TIME AS OF '<utc timestamp>'` in Hive and Impala, `TIMESTAMP AS OF` in Spark; the timestamp is UTC. See the stretch for an example with `now() - interval …`.

`history` shows the lineage of the snapshots. The column `is_current_ancestor` is `true` for every snapshot that leads to the current table — it becomes interesting after a rollback in section 9:

```bash
hql "SELECT * FROM ws_${WORKSHOP_USER}.ice_meter.history ORDER BY made_current_at"
```

What this replaces: with plain external tables, "what did the table look like at 09:00?" is only answerable if somebody kept a copy. And because snapshots are read-only, an auditor's query on `SNAP_FIRST` gives the same result next week as today, no matter what the pipelines change in the meantime.

**Check question:** Hive and Impala use the **current** schema when they read an old snapshot. What would that show if you had added a column after the snapshot was taken?

---

## 7. Snapshot isolation — readers and files

**Goal:** Show that a change never touches the files an earlier snapshot refers to.

Take the current snapshot as a reference point and change a value in Hive:

```bash
export SNAP_NOW=$(beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
  -e "SELECT snapshot_id FROM ws_${WORKSHOP_USER}.ice_meter.snapshots ORDER BY committed_at DESC LIMIT 1" | tail -1)
hdfs dfs -ls "${ICE_META}/data/station_id=TS-101"
```

```sql
UPDATE ice_meter SET frequency_hz = 50.00 WHERE station_id = 'TS-101';
```

The reader pinned to the old snapshot and the reader of the current table see different values at the same moment:

```bash
hql "SELECT frequency_hz, COUNT(*) AS n FROM ice_meter FOR SYSTEM_VERSION AS OF ${SNAP_NOW} WHERE station_id = 'TS-101' GROUP BY frequency_hz ORDER BY frequency_hz"
hql "SELECT frequency_hz, COUNT(*) AS n FROM ice_meter WHERE station_id = 'TS-101' GROUP BY frequency_hz ORDER BY frequency_hz"
hdfs dfs -ls "${ICE_META}/data/station_id=TS-101"
```

The listing now has **more** files than before and none of the old ones was modified or removed. That is **snapshot isolation**:

- A query reads the table metadata **once**, at the start, and then reads exactly the files of that snapshot. A change that is committed while the query runs creates new files and a new snapshot; the running query never sees it.  
- A commit is one atomic step (the metadata pointer in the Metastore). Readers see the table either before or after a change, never half of it. Compare that with `INSERT OVERWRITE` in section 1, where a reader could meet a partition that was just emptied.  
- Writers do not block readers. Two writers that change the same table at the same time use **optimistic concurrency**: each prepares its files, then tries to commit against the snapshot it started from. If another commit came first, one writer retries or fails — it never silently overwrites the other. Your instructor shows this live.

The price: old files stay on HDFS until you expire the snapshots (section 9).

**Check question:** A report job runs for 20 minutes while the pipeline commits every 5 minutes. Which data does the report see — and what must you keep so that a long-running report does not fail?

---

## 8. Advanced joins

**Goal:** Go beyond `JOIN … ON a = b`: semi and anti joins, outer joins, range joins, self joins, aggregate-then-join, and a diff between two snapshots. The queries run on `ice_meter` and the small tables from section 0: `stations`, `market_prices`. Terminal 1 (Beeline).

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

The second and third statement are two spellings of an **anti join** (rows without a match): `LEFT JOIN … IS NULL`, and `NOT EXISTS`. The semi join returns `TS-305`; both anti joins return `TS-204`. They give the same plan in most cases — use whichever reads better.

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

**Range join — "which interval does this reading fall into?"** Instead of cutting strings to the hour, join each reading to the price interval that contains it. The condition is a range, not an equality; the extra equality on the date keeps Hive from comparing every reading with every price:

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

**Self join — "compare a row with the previous one."** Join `ice_meter` to itself on the same station and the time 15 minutes earlier. A `LEFT JOIN` keeps the first reading of each station (and readings after a gap) with `NULL` as the previous value:

```sql
WITH m AS (
  SELECT station_id,
         CAST(REPLACE(SUBSTR(ts_utc, 1, 19), 'T', ' ') AS TIMESTAMP) AS ts,
         transformer_load_pct
  FROM ice_meter
)
SELECT c.station_id, c.ts, c.transformer_load_pct,
       ROUND(c.transformer_load_pct - p.transformer_load_pct, 1) AS delta_pct
FROM m c
LEFT JOIN m p
  ON p.station_id = c.station_id AND p.ts = c.ts - INTERVAL '15' MINUTE
ORDER BY c.station_id, c.ts;
```

Station `TS-204` has a gap at `08:15` (you deleted those readings), so its first reading after the gap has no previous value. Window functions (`LAG`) solve this more elegantly; you see them in the advanced Hive module.

**Aggregate first, then join.** Joining readings with prices *row by row* and then aggregating is fine for 13 rows and expensive for 13 billion. Reduce each side to the join grain first, then join the small results — here the cost per station, enriched with the district:

```sql
WITH priced AS (
  SELECT m.station_id, m.active_power_kw * 0.25 AS kwh, p.price_ct_kwh
  FROM ice_meter m
  JOIN market_prices p
    ON SUBSTR(m.ts_utc, 1, 10) = SUBSTR(p.timestamp_start, 1, 10)
   AND m.ts_utc >= p.timestamp_start AND m.ts_utc < p.timestamp_end
), per_station AS (
  SELECT station_id, ROUND(SUM(kwh), 1) AS kwh, ROUND(SUM(kwh * price_ct_kwh) / 100, 2) AS cost_eur
  FROM priced
  GROUP BY station_id
)
SELECT s.station_id, s.municipality, s.district, ps.kwh, ps.cost_eur
FROM stations s
JOIN per_station ps ON ps.station_id = s.station_id
ORDER BY ps.cost_eur DESC;
```

**Join two snapshots — what changed?** Only a table format lets you do this: a `FULL OUTER JOIN` of the table as of `SNAP_FIRST` with the table now, on the key of a reading. Everything on only one side was deleted or inserted, and a difference in values means a change. Run it from terminal 2, where `SNAP_FIRST` is defined (section 6):

```bash
hql "
WITH old AS (SELECT * FROM ice_meter FOR SYSTEM_VERSION AS OF ${SNAP_FIRST}),
     cur AS (SELECT * FROM ice_meter)
SELECT COALESCE(c.station_id, o.station_id) AS station_id,
       COALESCE(c.ts_utc, o.ts_utc) AS ts_utc,
       CASE WHEN o.ts_utc IS NULL THEN 'inserted'
            WHEN c.ts_utc IS NULL THEN 'deleted'
            WHEN o.quality_flag <> c.quality_flag OR o.comm_status <> c.comm_status
                 OR o.active_power_kw <> c.active_power_kw THEN 'changed'
            ELSE 'unchanged' END AS change
FROM old o
FULL OUTER JOIN cur c ON o.station_id = c.station_id AND o.ts_utc = c.ts_utc
ORDER BY station_id, ts_utc"
```

You should see 17 rows: 7 unchanged, 4 changed, 4 deleted, 2 inserted — a complete audit trail of sections 3–5 from one query. With external tables you would need a copy of the old data for this.

**Join strategies.** Look at how Hive runs a join with a tiny table. `stations` has three rows, so Hive can send it to every task (a **map join**) and skip the shuffle:

```sql
EXPLAIN
SELECT m.station_id, s.district, COUNT(*) FROM ice_meter m JOIN stations s ON m.station_id = s.station_id GROUP BY m.station_id, s.district;
```

Look for `Map Join Operator` in the plan. Switch the automatic conversion off and compare — now both inputs are shuffled and joined in a reducer (`Merge Join Operator`):

```sql
SET hive.auto.convert.join=false;
EXPLAIN
SELECT m.station_id, s.district, COUNT(*) FROM ice_meter m JOIN stations s ON m.station_id = s.station_id GROUP BY m.station_id, s.district;
SET hive.auto.convert.join=true;
```

For a big fact table and a small dimension, the map join is the good plan. Impala has the same choice (`/* +BROADCAST */` or `/* +SHUFFLE */` hints), and Spark has `/*+ BROADCAST(s) */`.

**Check question:** The range join returned 13 rows. After somebody loads a second `market_prices` file for the same day (overlapping hours), what happens to the count — and how do you notice?

---

## 9. Undo and clean up — rollback and expire snapshots

**Goal:** Recover from a wrong statement, then remove history you no longer need and see the files go.

First remember the good state, then make a mistake. Terminal 2:

```bash
export SNAP_GOOD=$(beeline -u "${HS2_URL}" --silent=true --showHeader=false --outputformat=tsv2 \
  -e "SELECT snapshot_id FROM ws_${WORKSHOP_USER}.ice_meter.snapshots ORDER BY committed_at DESC LIMIT 1" | tail -1)
echo "${SNAP_GOOD}"
```

Terminal 1. Somebody wanted to delete the `WARN`/`REVIEWED` readings, but typed the wrong condition:

```sql
DELETE FROM ice_meter WHERE quality_flag = 'OK';
SELECT COUNT(*) FROM ice_meter;
```

The table is empty — every remaining reading had the flag `OK`. Roll the table back to the good snapshot — a metadata operation, no data is copied:

```bash
hql "ALTER TABLE ice_meter EXECUTE ROLLBACK(${SNAP_GOOD})"
hql "SELECT COUNT(*) FROM ice_meter"
hql "SELECT snapshot_id, parent_id, is_current_ancestor FROM ws_${WORKSHOP_USER}.ice_meter.history ORDER BY made_current_at"
```

The count is 13 again. In the history the wrong `DELETE` is still listed, but with `is_current_ancestor = false`: it is not part of the table's lineage any more. Impala uses the same statement (`ALTER TABLE … EXECUTE ROLLBACK(<id>)`), Spark has `CALL spark_catalog.system.rollback_to_snapshot('<db>.ice_meter', <id>)`.

Compare with section 1, where the same mistake on an external table would have been permanent.

Now the cleanup. Every snapshot keeps its files. Count the files, expire everything older than now, and count again:

```bash
hdfs dfs -count "${ICE_META}/data" "${ICE_META}/metadata"
hql "ALTER TABLE ice_meter EXECUTE EXPIRE_SNAPSHOTS(CURRENT_TIMESTAMP)"
hdfs dfs -count "${ICE_META}/data" "${ICE_META}/metadata"
hdfs dfs -ls -R "${ICE_META}/data"
hql "SELECT COUNT(*) FROM ice_meter FOR SYSTEM_VERSION AS OF ${SNAP_FIRST}"
```

`-count` prints directories, files, and bytes. The number of files under `data` goes down: Iceberg deletes data and delete files that no remaining snapshot refers to. Only the current snapshot is left, so time travel to `SNAP_FIRST` now fails with an error that the snapshot cannot be found. The `metadata` folder keeps its old `*.metadata.json` files unless the table property `write.metadata.delete-after-commit.enabled` is set.

Expiring is a decision about **how long you want to keep history** — for audits, for rollbacks, for GDPR deletes (an expired snapshot no longer contains the deleted person's data). A production table gets a schedule: keep the last 30 days, expire the rest.

**Check question:** A "right to be forgotten" request means a customer's rows must disappear from the table **and** from its history. Which two steps are needed?

---

## 10. Compare — which engine for which job

**Goal:** Put the three engines side by side and decide where each belongs in the pilot.

Fill in your own notes; the trainer discusses them in the group:

| Task | Hive | Impala | Spark |
|------|------|--------|-------|
| Batch load, nightly `MERGE` of correction files | | | |
| Analyst query on the latest data | | | |
| Large rewrite / compaction / migration of old tables | | | |
| Audit query "as of last Tuesday" | | | |

What you saw in the lab: all three engines read and write the **same** Iceberg table; Hive and Spark can do copy-on-write and merge-on-read, Impala only merge-on-read and only on Parquet; snapshot list, time travel, rollback, and expiry work from every engine, with slightly different syntax. For the section 1 patterns there is nothing left to do by hand on Iceberg: `UPDATE`, `DELETE`, `MERGE`, and a delete of a whole station (a partition) are plain SQL.

When Iceberg is **not** the answer: raw landing zones where files arrive from outside (keep them as external tables), and tiny reference tables nobody changes.

**Check question:** Which tables of your pilot (smart-meter readings, market prices, weather, station master data) would you make Iceberg tables first, and which stay external CSV or Parquet?

---

## Stretch (optional)

- **Copy-on-write instead of merge-on-read:** `ALTER TABLE ice_meter SET TBLPROPERTIES ('write.delete.mode'='copy-on-write', 'write.update.mode'='copy-on-write');` in Hive, then run one `DELETE` and list `${ICE_META}/data` — this time Hive rewrites the affected data file and writes **no** delete file. Set the properties back to `merge-on-read` when you are done (Impala cannot write to a table in copy-on-write mode).  
- **Time travel by time:** `SELECT COUNT(*) FROM ice_meter FOR SYSTEM_TIME AS OF current_timestamp - interval 30 minutes;` — it works as soon as the table is older than that. Hive and Impala read the timestamp as UTC.  
- **Migrate a table in place:** in Hive, create a Parquet table with `CREATE EXTERNAL TABLE meter_parquet STORED AS PARQUET AS SELECT * FROM landisgyr_csv;`, then run `ALTER TABLE meter_parquet SET TBLPROPERTIES ('storage_handler'='org.apache.iceberg.mr.hive.HiveIcebergStorageHandler');`. The table becomes an Iceberg table without rewriting the data files. Look at `${HIVE_EXT}/meter_parquet` afterwards: a new `metadata` folder next to the old files. The row count stays 15. (Spark has `CALL spark_catalog.system.migrate(…)` for the same job.)  
- **Partition evolution:** `ALTER TABLE ice_meter SET PARTITION SPEC (station_id, hour(<timestamp column>))` needs a timestamp column; the lab table has strings. Try it on a new Iceberg table created with `CAST(REPLACE(SUBSTR(ts_utc, 1, 19), 'T', ' ') AS TIMESTAMP)` as `ts`: old data stays in the old layout, new data uses the new one, and queries work on both.  
- **Compact small files:** every `INSERT` adds files. In Spark: `CALL spark_catalog.system.rewrite_data_files('<db>.ice_meter')`; the user who compacts needs `ALL` on the table in Ranger.  
- **Drop an Iceberg table:** create a throw-away table (`CREATE EXTERNAL TABLE t … STORED BY ICEBERG` and an `INSERT`), check `SHOW TBLPROPERTIES t`, drop it and look at its folder. Do the files stay (external) or go (`external.table.purge`)? Compare with what `DROP TABLE` did to the external CSV table in section 0.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket, `HS2_URL`, and the tables you created):

```bash
./07-lakehouse-iceberg/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
