# Hive hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need two terminals on the edge node: one for `beeline` (SQL) and one for `hdfs` (files). Sections 1–6 are about **external tables** and files, sections 7–8 about **managed tables**, sections 9–11 about everyday SQL.

Set your Kerberos identity and paths once in **both** terminals. `WORKSHOP_USER` is the short name you use with `kinit` (same account as on the edge node). `HIVE_LAB` holds shared module files on HDFS (prepared landing data). `HIVE_WORK` is your own folder for table data — every table you create in this lab points into it. `HS2_URL` is the HiveServer2 JDBC URL from your workshop handout.

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export HIVE_LAB="${WORKSHOP_ROOT}/03-hive"
export HIVE_WORK="${HIVE_LAB}/work/${WORKSHOP_USER}"
export HS2_URL="<jdbc-url-from-your-handout>"
```

Hive stores **no data itself**: the Metastore keeps table definitions (names, columns, locations), and the data stays as files in HDFS. Every query you run compiles into a Tez application on YARN — the same engine you compared with MapReduce in the YARN lab.

---

## 0. Orient — connect and create your database

**Goal:** Open a Beeline session with your variables and create a database that is yours alone.

Start Beeline in the first terminal. The `--hivevar` options define variables you can use in SQL as `${hivevar:name}`, so you never type your username or paths by hand:

```bash
beeline -u "${HS2_URL}" \
  --hivevar ws_user="${WORKSHOP_USER}" \
  --hivevar ws_root="${WORKSHOP_ROOT}" \
  --hivevar ws_work="${HIVE_WORK}"
```

Everything in the following blocks marked `sql` goes into this Beeline session. See what exists, create your database, and look at where Hive will put its data:

```sql
SHOW DATABASES;
CREATE DATABASE IF NOT EXISTS ws_${hivevar:ws_user};
USE ws_${hivevar:ws_user};
SELECT current_database(), current_user();
DESCRIBE DATABASE EXTENDED ws_${hivevar:ws_user};
```

Note the two locations in the `DESCRIBE` output: one for **external** tables and one for **managed** tables. You will see in sections 1 and 7 why they are separate.

In the second terminal, create your work folder. Hive tables in this lab keep their files here:

```bash
hdfs dfs -mkdir -p "${HIVE_WORK}"
hdfs dfs -ls "${HIVE_LAB}"
```

You should see `landing` and `work`.

**Check question:** Which component knows that a table named `landisgyr_csv` exists — HDFS or the Metastore? Where is the data?

Optional: open **Hue → Editor → Hive** and run `SHOW DATABASES;` there too.

---

## 1. External table over a CSV copy

**Goal:** Copy a smart-meter CSV into your own folder and put an external table on top of it.

A table `LOCATION` is a **folder**, and Hive reads every file in it. You copy the file into a folder you own so the table has a folder of its own. In the second terminal:

```bash
hdfs dfs -mkdir -p "${HIVE_WORK}/landisgyr"
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_WORK}/landisgyr/"
hdfs dfs -ls "${HIVE_WORK}/landisgyr"
```

Now define the table. Hive maps CSV fields **by position**, not by header name — so you can choose your own column names. Timestamps stay `STRING` for now (section 2 shows why), and the header line is skipped with a table property:

```sql
CREATE EXTERNAL TABLE landisgyr_csv (
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
LOCATION '${hivevar:ws_work}/landisgyr'
TBLPROPERTIES ('skip.header.line.count'='1');
```

Query it. The first statement only reads the file; the second needs a real job (watch the Tez progress in Beeline):

```sql
SELECT * FROM landisgyr_csv LIMIT 5;
SELECT COUNT(*) FROM landisgyr_csv;
```

Inspect what the Metastore stored. Look for `Table Type`, `Location`, and the serde/format lines:

```sql
DESCRIBE FORMATTED landisgyr_csv;
SHOW CREATE TABLE landisgyr_csv;
```

You should see `EXTERNAL_TABLE` and a location that points into your `HIVE_WORK` folder.

The table **is** the folder. Drop a second file into it, and query again without telling Hive anything:

```bash
hdfs dfs -cp "${HIVE_WORK}/landisgyr/sample-landisgyr-data.csv" "${HIVE_WORK}/landisgyr/second-copy.csv"
```

```sql
SELECT COUNT(*) FROM landisgyr_csv;
```

The count doubles. Remove the extra file and count again:

```bash
hdfs dfs -rm -skipTrash "${HIVE_WORK}/landisgyr/second-copy.csv"
```

```sql
SELECT COUNT(*) FROM landisgyr_csv;
```

**Check question:** Nobody ran a load command, yet new rows appeared. What does that mean for a pipeline that lands files into a folder that a table already points at?

---

## 2. Schema on read — and what DROP does

**Goal:** See what Hive does when the table definition does not match the file, and what `DROP TABLE` does to external data.

Define a second table on the **same folder** with wrong types: a timestamp that is not in Hive's format, and a number column that contains `L1`/`L2`/`L3`. It also declares only five of the fourteen columns:

```sql
CREATE EXTERNAL TABLE landisgyr_wrong (
  ts_utc TIMESTAMP,
  station_id INT,
  device_id STRING,
  phase INT,
  active_power_kw STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:ws_work}/landisgyr'
TBLPROPERTIES ('skip.header.line.count'='1');

SELECT * FROM landisgyr_wrong LIMIT 5;
```

You should get no error, but `NULL` in every column whose type does not fit. Hive checks types when it **reads**, not when you create the table, and a failed conversion becomes `NULL`.

Now drop that table and check the files:

```sql
DROP TABLE landisgyr_wrong;
```

```bash
hdfs dfs -ls "${HIVE_WORK}/landisgyr"
```

```sql
SELECT COUNT(*) FROM landisgyr_csv;
```

The CSV is still there and `landisgyr_csv` still works: dropping an **external** table removes only the metadata.

**Check question:** A nightly job reads a column as `INT`, but the source system starts sending `1.5`. What does Hive do — and how would you notice?

---

## 3. Partitions — ADD PARTITION and MSCK REPAIR

**Goal:** Build a partitioned external table over folders that arrive from outside, and teach Hive about each partition.

A **partition** is a sub-folder named `column=value`. Hive reads only the folders a query needs. Look at the prepared landing area — one folder per station — and at one file in it:

```bash
hdfs dfs -ls -R "${HIVE_LAB}/landing/landisgyr_by_station"
hdfs dfs -cat "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-101/*" | head -3
```

Compare the rows with the original CSV: the `station_id` column is gone. In a partitioned table the value lives in the **folder name**, not in the file.

Create your table folder and copy **only one** station into it:

```bash
hdfs dfs -mkdir -p "${HIVE_WORK}/landisgyr_by_station"
hdfs dfs -cp "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-101" "${HIVE_WORK}/landisgyr_by_station/"
hdfs dfs -ls -R "${HIVE_WORK}/landisgyr_by_station"
```

Define the table. `station_id` is declared in `PARTITIONED BY`, not in the column list. Recent CDP versions can discover new folders in the background; the property below switches that off so you can see the manual steps:

```sql
CREATE EXTERNAL TABLE landisgyr_by_station (
  ts_utc STRING,
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
PARTITIONED BY (station_id STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:ws_work}/landisgyr_by_station'
TBLPROPERTIES ('discover.partitions'='false');

SHOW PARTITIONS landisgyr_by_station;
SELECT COUNT(*) FROM landisgyr_by_station;
```

The folder holds data, but you should see no partitions and a count of `0`. The files exist on HDFS; the Metastore does not know about them yet. Register the partition:

```sql
ALTER TABLE landisgyr_by_station ADD PARTITION (station_id='TS-101')
  LOCATION '${hivevar:ws_work}/landisgyr_by_station/station_id=TS-101';

SHOW PARTITIONS landisgyr_by_station;
SELECT station_id, COUNT(*) FROM landisgyr_by_station GROUP BY station_id;
```

Two more stations arrive. Copy them into the table folder and query again:

```bash
hdfs dfs -cp "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-204" "${HIVE_WORK}/landisgyr_by_station/"
hdfs dfs -cp "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-305" "${HIVE_WORK}/landisgyr_by_station/"
```

```sql
SELECT station_id, COUNT(*) FROM landisgyr_by_station GROUP BY station_id;
```

You should still see only `TS-101`. Instead of one `ADD PARTITION` per folder, let Hive scan the table folder and register everything it finds:

```sql
MSCK REPAIR TABLE landisgyr_by_station;
SHOW PARTITIONS landisgyr_by_station;
SELECT station_id, COUNT(*) FROM landisgyr_by_station GROUP BY station_id;
```

**Partition pruning.** The benefit of partitions is that Hive reads only the folders a query needs. `EXPLAIN DEPENDENCY` shows which partitions a query will read, without running it. Look at the `input_partitions` list. Start with a filter on the partition column:

```sql
EXPLAIN DEPENDENCY
SELECT ts_utc, active_power_kw FROM landisgyr_by_station WHERE station_id = 'TS-305';
```

You should see a single partition, `station_id=TS-305`. Now widen the filter to two stations, and then remove it:

```sql
EXPLAIN DEPENDENCY
SELECT ts_utc, active_power_kw FROM landisgyr_by_station WHERE station_id IN ('TS-101', 'TS-204');

EXPLAIN DEPENDENCY
SELECT ts_utc, active_power_kw FROM landisgyr_by_station;
```

The list grows to two and then three partitions. Finally filter on a **normal column** instead of the partition column:

```sql
EXPLAIN DEPENDENCY
SELECT ts_utc, active_power_kw FROM landisgyr_by_station WHERE quality_flag = 'WARN';
```

All three partitions are read: Hive cannot know which folders contain `WARN` rows without opening the files.

For the full plan of the pruned query, use `EXPLAIN EXTENDED` and scroll to the `Path -> Alias` and `Path -> Partition` sections. They list the HDFS folders the scan will read — compare them with your `hdfs dfs -ls -R` output from above:

```sql
EXPLAIN EXTENDED
SELECT ts_utc, active_power_kw FROM landisgyr_by_station WHERE station_id = 'TS-305';
```

Run `EXPLAIN EXTENDED` again for the unfiltered query and compare how many folders appear.

**Check question:** Which of your four queries would read the least data if the table held two years of daily partitions and you only needed one day? What must the table be partitioned by for that to work?

**Check question:** A daily export job writes a new `dt=…` folder every night. Files are there in the morning, but the dashboard shows yesterday's data. What step is missing, and which two ways do you now have to fix it?

---

## 4. File formats — CSV, ORC, Parquet on HDFS

**Goal:** Store the same rows in three formats and look inside the files to see how columnar storage differs from text.

Fifteen rows are too few to see any difference. Build the data in three steps. First a CSV table with jittered copies of the meter rows (15 × 1000 = 15,000 rows):

```sql
CREATE EXTERNAL TABLE meter_csv (
  ts_utc STRING,
  station_id STRING,
  active_power_kw DOUBLE,
  reactive_power_kvar DOUBLE,
  voltage_v DOUBLE,
  current_a DOUBLE,
  transformer_load_pct DOUBLE,
  quality_flag STRING,
  event_code STRING,
  comm_status STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:ws_work}/meter_csv';

INSERT INTO meter_csv
SELECT ts_utc, station_id,
       ROUND(active_power_kw + rand() * 20, 1),
       ROUND(reactive_power_kvar + rand() * 5, 1),
       ROUND(voltage_v + rand() * 2, 1),
       ROUND(current_a + rand() * 30, 1),
       ROUND(transformer_load_pct + rand() * 5, 1),
       quality_flag, event_code, comm_status
FROM landisgyr_csv
LATERAL VIEW explode(split(space(999), ' ')) r AS i;
```

Then two tables with the same columns, stored as ORC and as Parquet, filled from `meter_csv` so every format holds identical data:

```sql
CREATE EXTERNAL TABLE meter_orc (
  ts_utc STRING,
  station_id STRING,
  active_power_kw DOUBLE,
  reactive_power_kvar DOUBLE,
  voltage_v DOUBLE,
  current_a DOUBLE,
  transformer_load_pct DOUBLE,
  quality_flag STRING,
  event_code STRING,
  comm_status STRING
)
STORED AS ORC
LOCATION '${hivevar:ws_work}/meter_orc';

CREATE EXTERNAL TABLE meter_parquet (
  ts_utc STRING,
  station_id STRING,
  active_power_kw DOUBLE,
  reactive_power_kvar DOUBLE,
  voltage_v DOUBLE,
  current_a DOUBLE,
  transformer_load_pct DOUBLE,
  quality_flag STRING,
  event_code STRING,
  comm_status STRING
)
STORED AS PARQUET
LOCATION '${hivevar:ws_work}/meter_parquet';

INSERT INTO meter_orc SELECT * FROM meter_csv;
INSERT INTO meter_parquet SELECT * FROM meter_csv;
```

Check the row counts, then switch to the second terminal. Compare how much space each format needs, and list the files Hive wrote:

```sql
SELECT 'csv', COUNT(*) FROM meter_csv
UNION ALL SELECT 'orc', COUNT(*) FROM meter_orc
UNION ALL SELECT 'parquet', COUNT(*) FROM meter_parquet;
```

```bash
hdfs dfs -du -h "${HIVE_WORK}"
hdfs dfs -ls "${HIVE_WORK}/meter_csv" "${HIVE_WORK}/meter_orc" "${HIVE_WORK}/meter_parquet"
```

Same rows, different sizes. Now look inside, starting with the text file. Use the file name from the listing:

```bash
hdfs dfs -cat "<csv-file>" | head -3
```

You can read it. Now the ORC file: the first bytes are a magic marker, and `orcfiledump` prints the file footer — row count, compression, and **statistics per column**:

```bash
hdfs dfs -cat "<orc-file>" | head -c 3; echo
hive --orcfiledump "<orc-file>" | head -150
```

Scroll through the dump. Columns are numbered in table order starting at `1` (`0` is the whole row). Find the `Stripes:` section: every column has its own `Stream` lines (`DATA`, `LENGTH`, `DICTIONARY_DATA`) with a byte `length`. Compare the stream sizes of the numeric columns with `station_id`, `event_code`, and `comm_status`.

Parquet stores columns in **column chunks** and keeps the schema in a footer at the end of the file. Check the magic marker and read the end of the file:

```bash
hdfs dfs -cat "<parquet-file>" | head -c 4; echo
hdfs dfs -cat "<parquet-file>" | tail -c 2000 | strings
```

You should see `PAR1` and, among the readable fragments, your column names and values like `TS-101`.

**Check question:** Why are `event_code` and `comm_status` almost free in ORC while `current_a` is not? Which format would you pick for a curated table that analysts query by a few columns — and why would you keep the CSV only in the landing area?

---

## 5. UPDATE and DELETE on external tables

**Goal:** Try to change single rows in an external table, read the error, and see why re-running `INSERT INTO` is dangerous.

A data engineer finds that all `WARN` readings were reviewed and wants to flag them. Try an `UPDATE` and a `DELETE`:

```sql
UPDATE meter_orc SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM meter_orc WHERE station_id = 'TS-305';
```

Both statements should fail with an error saying the table is **not transactional**. Files on HDFS cannot be edited in place, and external tables have no transaction layer that tracks row changes.

What does work is adding data. Run the same insert a second time, as a job would after a retry:

```sql
SELECT COUNT(*) FROM meter_orc;
INSERT INTO meter_orc SELECT * FROM meter_csv;
SELECT COUNT(*) FROM meter_orc;
```

```bash
hdfs dfs -ls "${HIVE_WORK}/meter_orc"
```

The count doubled and there is a second file. `INSERT INTO` **appends**. Replace the table content instead:

```sql
INSERT OVERWRITE TABLE meter_orc SELECT * FROM meter_csv;
SELECT COUNT(*) FROM meter_orc;
```

```bash
hdfs dfs -ls "${HIVE_WORK}/meter_orc"
```

You should be back at 15,000 rows with a single file.

**Check question:** An hourly job uses `INSERT INTO` and fails halfway, then the scheduler restarts it. What does the table look like afterwards?

---

## 6. Idempotent workflows — overwrite, rewrite, merge

**Goal:** Replace row-level `UPDATE`, `DELETE`, and `MERGE` with patterns that are safe to run twice: overwrite a partition, rewrite it, drop it.

A job is **idempotent** if running it twice leaves the same result as running it once. With external tables, the unit of change is the partition. Create a partitioned ORC table and load it from the small CSV table with **dynamic partitioning** (Hive takes the partition values from the last column of the `SELECT`):

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
STORED AS ORC
LOCATION '${hivevar:ws_work}/meter_part';

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

**Delete a whole partition.** Drop the partition of `TS-204`, then look at HDFS:

```sql
ALTER TABLE meter_part DROP PARTITION (station_id = 'TS-204');
SHOW PARTITIONS meter_part;
```

```bash
hdfs dfs -ls "${HIVE_WORK}/meter_part"
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
hdfs dfs -rm -r -skipTrash "${HIVE_WORK}/meter_part/station_id=TS-204"
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

**Merge by rewriting.** A correction file arrives for `TS-101`: one corrected reading (`08:45`) and one new reading (`09:15`). Create the file locally, with a header like the original CSV, and put it into its own folder:

```bash
cat > "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" <<'EOF'
timestamp,station_id,device_id,phase,active_power_kw,reactive_power_kvar,voltage_v,current_a,power_factor,frequency_hz,transformer_load_pct,quality_flag,event_code,comm_status
2026-01-15T08:45:00Z,TS-101,LG-TS-101-A,L1,203.9,38.8,229.0,318.0,0.980,49.99,68.9,OK,,ONLINE
2026-01-15T09:15:00Z,TS-101,LG-TS-101-A,L1,199.5,38.1,229.6,313.0,0.981,50.00,67.4,OK,,ONLINE
EOF
hdfs dfs -mkdir -p "${HIVE_WORK}/landisgyr_changes"
hdfs dfs -put -f "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" "${HIVE_WORK}/landisgyr_changes/"
```

`LIKE` copies the column definitions and settings of `landisgyr_csv` — including the skipped header line, which is why the file has one:

```sql
CREATE EXTERNAL TABLE landisgyr_changes LIKE landisgyr_csv
LOCATION '${hivevar:ws_work}/landisgyr_changes';

SELECT * FROM landisgyr_changes;
```

A merge has two halves: keep the existing rows that were **not** corrected, and add all rows from the correction file. Write both back into the partition (safe to run twice):

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

You should see six readings for `TS-101`: the `08:45` flag is now `OK` and `09:15` is new. Section 8 solves the same task with a real `MERGE` statement.

**Check question:** Why is `INSERT OVERWRITE … PARTITION` safe to re-run while `INSERT INTO` is not? What happens to a station that is in the table but missing from the source when you run a dynamic overwrite?

---

## 7. Managed tables

**Goal:** Create a managed table and find out what is different from an external one — location, ownership, and transactions.

A **managed** table belongs to Hive: Hive decides where the files go, and `DROP TABLE` deletes them. In CDP, managed tables are **transactional** (ACID) ORC tables by default. Create one from your CSV table (CTAS = create table as select):

```sql
CREATE TABLE landisgyr_managed AS
SELECT * FROM landisgyr_csv;

SELECT COUNT(*) FROM landisgyr_managed;
DESCRIBE FORMATTED landisgyr_managed;
```

In the `DESCRIBE` output compare with section 1: `Table Type`, `Location` (the managed warehouse, not your folder), the `InputFormat`, and in `Table Parameters` the entries `transactional` and `transactional_properties`.

Try to look at the files in the second terminal. Use the location from the `DESCRIBE` output:

```bash
hdfs dfs -ls -R "<managed-table-location>"
```

Depending on your cluster policies you either see `base_…` / `delta_…` folders with ORC files, or `Permission denied`. Both are expected: the files belong to the `hive` service user, and you work with them through SQL — not through HDFS commands.

Now drop a throw-away managed table and compare with section 2:

```sql
CREATE TABLE tmp_managed AS SELECT * FROM landisgyr_csv;
DESCRIBE FORMATTED tmp_managed;
DROP TABLE tmp_managed;
```

Dropping a managed table deletes its data. Your instructor shows the folder before and after in a live demo.

**Check question:** Who should own the raw landing data — an external or a managed table? Who should own a curated table that only Hive writes? Why?

---

## 8. UPDATE, DELETE, MERGE on managed tables

**Goal:** Change single rows with plain SQL and see what Hive does on HDFS in the background.

First the `UPDATE` that failed in section 5 — now on a transactional table:

```sql
UPDATE landisgyr_managed SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
SELECT station_id, quality_flag, COUNT(*) FROM landisgyr_managed GROUP BY station_id, quality_flag;
```

Then a `DELETE`:

```sql
DELETE FROM landisgyr_managed WHERE station_id = 'TS-305' AND event_code = 'HIGH_LOAD';
SELECT station_id, COUNT(*) FROM landisgyr_managed GROUP BY station_id;
```

Both statements work. HDFS files are still immutable, so Hive does not edit them: each change writes a small **delta** folder, and readers merge the deltas on the fly. If you can read the table location (section 7), list it again and look for `delta_…` and `delete_delta_…` folders:

```bash
hdfs dfs -ls -R "<managed-table-location>"
```

Many small changes mean many deltas, so Hive **compacts** them in the background. Ask for a compaction and watch its state:

```sql
SHOW COMPACTIONS;
ALTER TABLE landisgyr_managed COMPACT 'major';
SHOW COMPACTIONS;
```

Now the correction file from section 6, applied with a real `MERGE`: update the row that exists, insert the row that does not. The match condition is the key of a reading (station + timestamp):

```sql
MERGE INTO landisgyr_managed AS t
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

SELECT ts_utc, quality_flag FROM landisgyr_managed WHERE station_id = 'TS-101' ORDER BY ts_utc;
```

Now run the same `MERGE` statement a second time (paste it again) and count the rows of `TS-101` afterwards:

```sql
SELECT COUNT(*) FROM landisgyr_managed WHERE station_id = 'TS-101';
```

The count is the same as after the first run: a `MERGE` on a unique key is idempotent.

**Check question:** Why does an `UPDATE` write new files instead of changing the old ones? What would happen to read performance if a job updated single rows every second and compaction never ran?

---

## 9. SQL basics — filter, aggregate, CASE, NULL, views

**Goal:** Use the everyday SQL features on the smart-meter data, including timestamps and empty values.

Look around your database first. These commands answer most “what do I have?” questions:

```sql
SHOW TABLES;
DESCRIBE landisgyr_csv;
```

The timestamp column is text like `2026-01-15T08:00:00Z`. Create a **view** that converts it into a real timestamp and turns empty event codes into `NULL`. A view stores only the query, no data:

```sql
CREATE VIEW landisgyr_v AS
SELECT CAST(REPLACE(SUBSTR(ts_utc, 1, 19), 'T', ' ') AS TIMESTAMP) AS ts,
       station_id, device_id, phase, active_power_kw, reactive_power_kvar,
       voltage_v, current_a, power_factor, frequency_hz, transformer_load_pct,
       quality_flag, NULLIF(event_code, '') AS event_code, comm_status
FROM landisgyr_csv;

SELECT * FROM landisgyr_v LIMIT 5;
```

Filter, sort, and limit — which readings put a transformer above 80 % load?

```sql
SELECT ts, station_id, active_power_kw, transformer_load_pct
FROM landisgyr_v
WHERE transformer_load_pct > 80
ORDER BY transformer_load_pct DESC;
```

Aggregate per station. `HAVING` filters **after** grouping, `WHERE` before:

```sql
SELECT station_id,
       COUNT(*) AS readings,
       ROUND(AVG(active_power_kw), 1) AS avg_kw,
       MAX(transformer_load_pct) AS max_load_pct,
       SUM(CASE WHEN quality_flag = 'WARN' THEN 1 ELSE 0 END) AS warnings
FROM landisgyr_v
GROUP BY station_id
HAVING MAX(transformer_load_pct) > 60
ORDER BY max_load_pct DESC;
```

Classify readings with `CASE`, and use date functions to aggregate by hour:

```sql
SELECT station_id, ts, transformer_load_pct,
       CASE WHEN transformer_load_pct >= 80 THEN 'HIGH'
            WHEN transformer_load_pct >= 50 THEN 'MEDIUM'
            ELSE 'LOW' END AS load_class
FROM landisgyr_v
ORDER BY station_id, ts;

SELECT date_format(ts, 'yyyy-MM-dd HH:00') AS hour_utc, station_id,
       ROUND(AVG(active_power_kw), 1) AS avg_kw
FROM landisgyr_v
GROUP BY date_format(ts, 'yyyy-MM-dd HH:00'), station_id
ORDER BY hour_utc, station_id;
```

Empty values are a classic trap. In the raw text table an empty `event_code` is an empty **string**, not `NULL`. Compare the two filters, then the view:

```sql
SELECT COUNT(*) FROM landisgyr_csv WHERE event_code IS NULL;
SELECT COUNT(*) FROM landisgyr_csv WHERE event_code = '';
SELECT COALESCE(event_code, 'NONE') AS event, COUNT(*) FROM landisgyr_v GROUP BY COALESCE(event_code, 'NONE');
```

**Check question:** One of the first two counts is zero. Which one, and why does that silently break a data-quality rule such as “count readings without an event”?

---

## 10. Joins

**Goal:** Combine meter readings with reference data, market prices, and weather — and spot a join that multiplies rows.

Create three small external tables directly on the **shared** workshop folders. You only define metadata; nothing is copied, and you cannot change these files:

```sql
CREATE EXTERNAL TABLE stations (
  station_id STRING,
  latitude DOUBLE,
  longitude DOUBLE,
  municipality STRING,
  district STRING,
  basemap_tile_hint STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:ws_root}/data/basemap'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE market_prices (
  timestamp_start STRING,
  timestamp_end STRING,
  market STRING,
  price_eur_mwh DOUBLE,
  price_ct_kwh DOUBLE,
  currency STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:ws_root}/data/awattar'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE weather_operator (
  ts_utc STRING,
  station_id STRING,
  station_name STRING,
  temperature_c DOUBLE,
  relative_humidity_pct DOUBLE,
  wind_speed_mps DOUBLE,
  precipitation_mm DOUBLE,
  pressure_hpa DOUBLE,
  quality_flag STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:ws_root}/data/operator_weather'
TBLPROPERTIES ('skip.header.line.count'='1');
```

**Inner join.** Add the district to each station's peak load. Rows without a match on either side disappear:

```sql
SELECT s.municipality, s.district, m.station_id, MAX(m.transformer_load_pct) AS max_load_pct
FROM landisgyr_v m
JOIN stations s ON m.station_id = s.station_id
GROUP BY s.municipality, s.district, m.station_id
ORDER BY max_load_pct DESC;
```

**Left join as anti-join.** Which stations never reported a `WARN`? Keep all stations, attach the ones with warnings, and keep the rows where nothing matched:

```sql
SELECT s.station_id, s.district
FROM stations s
LEFT JOIN (SELECT DISTINCT station_id FROM landisgyr_v WHERE quality_flag = 'WARN') w
  ON s.station_id = w.station_id
WHERE w.station_id IS NULL;
```

**Join on a derived key.** Meter readings arrive every 15 minutes, prices per hour. Join on the hour — the first 13 characters of both timestamps (`2026-01-15T08`) — to estimate the energy cost per station (15 minutes = 0.25 h; prices are in ct/kWh):

```sql
SELECT m.station_id,
       ROUND(SUM(m.active_power_kw * 0.25), 1) AS energy_kwh,
       ROUND(SUM(m.active_power_kw * 0.25 * p.price_ct_kwh) / 100, 2) AS cost_eur
FROM landisgyr_csv m
JOIN market_prices p ON SUBSTR(m.ts_utc, 1, 13) = SUBSTR(p.timestamp_start, 1, 13)
GROUP BY m.station_id
ORDER BY cost_eur DESC;
```

**A join that multiplies rows.** Join the readings to the operator weather on the timestamp only and compare the row counts:

```sql
SELECT COUNT(*) FROM landisgyr_csv;
SELECT COUNT(*) FROM landisgyr_csv m JOIN weather_operator w ON m.ts_utc = w.ts_utc;
```

You should see twice as many rows after the join. Find out why, then fix it by averaging the weather per timestamp first, in a common table expression (`WITH`):

```sql
SELECT ts_utc, COUNT(*) AS weather_rows FROM weather_operator GROUP BY ts_utc;

WITH weather AS (
  SELECT ts_utc, ROUND(AVG(temperature_c), 2) AS avg_temp_c
  FROM weather_operator
  GROUP BY ts_utc
)
SELECT m.station_id, m.ts_utc, m.transformer_load_pct, w.avg_temp_c
FROM landisgyr_csv m
JOIN weather w ON m.ts_utc = w.ts_utc
ORDER BY m.station_id, m.ts_utc;
```

**Check question:** Why did the join double the rows? What do you check about the join keys before you trust a join result in a pipeline?

---

## 11. Relate — Hive on Tez and YARN

**Goal:** Connect your SQL to what you learned in the YARN lab: query plans, statistics, and the Tez application behind Beeline.

Ask Hive for the plan of an aggregation. Look for `Tez`, the `Edges` section, and the vertices `Map 1` and `Reducer 2`:

```sql
EXPLAIN
SELECT station_id, MAX(transformer_load_pct) FROM landisgyr_csv GROUP BY station_id;
```

Run the query, then switch to the second terminal and list Tez applications on YARN. Look at the user and the application state:

```sql
SELECT station_id, MAX(transformer_load_pct) FROM landisgyr_csv GROUP BY station_id;
```

```bash
yarn application -list -appTypes TEZ
```

You should see at least one Tez application owned by the Hive service user — HiveServer2 keeps Tez sessions open, so your query used existing containers instead of starting a new application.

The optimizer plans better with statistics. Collect them for the table and look for `numRows` and `totalSize` in the table parameters:

```sql
ANALYZE TABLE landisgyr_csv COMPUTE STATISTICS;
DESCRIBE FORMATTED landisgyr_csv;
```

**Check question:** Compare the `EXPLAIN` output with the MapReduce and Tez runs from the YARN lab. Which part of the plan corresponds to the ApplicationMaster and the containers you saw there?

---

## Stretch (optional)

Run SQL non-interactively. Save a statement with a variable to a file and run it with `beeline -f` from the second terminal — the same way a scheduled job would:

```bash
cat > "/tmp/station-summary.sql.${WORKSHOP_USER}" <<'EOF'
USE ws_${hivevar:ws_user};
SELECT station_id, COUNT(*) AS readings FROM meter_part WHERE station_id = '${hivevar:station}' GROUP BY station_id;
EOF
beeline -u "${HS2_URL}" --hivevar ws_user="${WORKSHOP_USER}" --hivevar station=TS-305 \
  -f "/tmp/station-summary.sql.${WORKSHOP_USER}"
```

- Join three ways: `landisgyr_v` + `stations` + the OpenStreetMap context (`${WORKSHOP_ROOT}/data/openstreetmap`, filter `buffer_m = 250`) to relate peak load to the share of industrial area.  
- Schema change on an external table: `ALTER TABLE landisgyr_csv ADD COLUMNS (note STRING);` — what do old rows show? Does the CSV change?  
- Parquet footer with a proper tool: `parquet-tools meta "<parquet-file>"` (if it is on your `PATH`).  
- Clean up: `DROP DATABASE ws_${hivevar:ws_user} CASCADE;` and then list `${HIVE_WORK}` — which data is gone, which is still there?  
- Hue: run one of the join queries in the Hive editor and open the query in **Job Browser**.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket, `HS2_URL`, and your HDFS work folder):

```bash
./03-basics-hive/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
