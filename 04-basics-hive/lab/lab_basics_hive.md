# Hive hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need two terminals on the edge node: one for `beeline` (SQL) and one for `hdfs` (files). Sections 1–5 are about **external tables** and files, sections 6–7 about **managed tables**, sections 8–9 about everyday SQL and a first join, section 10 about table statistics. Window functions, complex joins, and more advanced functions are in the [advanced Hive lab](../../10-advanced-hive/lab/lab_advanced_hive.md).

Set your Kerberos identity and paths once in **both** terminals. `WORKSHOP_USER` is the short name you use with `kinit` (same account as on the edge node). `HIVE_LAB` holds shared module files on HDFS (prepared landing data). `HIVE_EXT` is the folder where Hive keeps the data of your **external** tables: the default external warehouse location, with one sub-folder per database. You never set a table location in this lab — Hive creates a folder per table below `HIVE_EXT`, and you copy files into it. `HIVE_MANAGED` is the matching folder for your **managed** tables (section 6), where Hive alone decides the layout.

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export HIVE_LAB="${WORKSHOP_ROOT}/04-hive"
export HIVE_EXT="/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db"   # adjust if needed
export HIVE_MANAGED="/warehouse/tablespace/managed/hive/${WORKSHOP_USER}.db"
```

Hive stores **no data itself**: the Metastore keeps table definitions (names, columns, locations), and the data stays as files in HDFS. Every query you run compiles into a Tez application on YARN — the same engine you compared with MapReduce in the YARN lab.

---

## Optional — use Hue instead of Beeline and `hdfs`

You can run most of this lab in the Hue web UI (URL from your handout). Beeline and the terminal stay the reference; use Hue if you prefer a browser.

**SQL in Hue.** Open **Editor → Hive** and paste the `sql` blocks of the lab unchanged. You do not need `--hivevar` in Hue: the lab SQL uses the variable `${ws_user}`, and as soon as the editor contains such a placeholder, Hue shows an **input field** for it below the editor and fills in your value when it runs the statement. It is the only variable in this lab: type your `WORKSHOP_USER` into the field.

Run a test statement, type your username into the field that appears, and run it again:

```sql
SELECT '${ws_user}';
```

The result is the name of your database.

Notes:

- The fields belong to the editor tab: they apply to every statement in the tab, and a new tab or a reloaded page needs them again.  
- Run a statement with **Ctrl+Enter** (the play button). Hue runs the statement under the cursor; select several statements to run them one after another.  
- Pick your database `<your_username>` in the database list on the left (or run `USE`) once section 0 has created it.

**Files in Hue.** Open **Files** (File Browser). Click the path at the top to type a path such as `/warehouse/tablespace/external/hive/<your_username>.db`. Then:

- Tick a file or folder, then **Actions → Copy**, and choose the target folder — this replaces `hdfs dfs -cp`. Copy a whole `station_id=…` folder the same way.  
- Click a file name to see its content (like `-cat`; ORC and Parquet look unreadable, which is the point). The listing shows size and owner (like `-ls` and `-du`).  
- Tick a file and **Delete forever** (not *Move to trash*) replaces `-rm -skipTrash`.

**What still needs a terminal:** the `heredoc` that creates the correction file in section 7 (in Hue: **New → File**, paste the three lines, save as `landisgyr-changes.csv` in the `landisgyr_changes` table folder), `hive --orcfiledump` and `strings` in section 4, and `beeline -f` in the stretch. The `bash` blocks in the other sections all have the File Browser equivalents above.

---

## 0. Orient — connect and create your database

**Goal:** Open a Beeline session with your variables and create a database that is yours alone.

Start Beeline in the first terminal. The `--hivevar` options define variables you can use in SQL as `${name}` (in Hue the same placeholders become input fields, see above), so you never type your username by hand:

```bash
beeline --hivevar ws_user="${WORKSHOP_USER}"
```

Everything in the following blocks marked `sql` goes into this Beeline session. See what exists, create your database, and look at where Hive will put its data:

```sql
SHOW DATABASES;
CREATE DATABASE IF NOT EXISTS ${ws_user};
USE ${ws_user};
SELECT current_database(), current_user();
DESCRIBE DATABASE EXTENDED ${ws_user};
```

Note the two locations in the `DESCRIBE` output: one for **external** tables and one for **managed** tables. You will see in sections 1 and 7 why they are separate. The external location is the folder `HIVE_EXT` you exported above.

In the second terminal, check that the folder exists and is still empty, and look at the shared landing data you use in section 3:

```bash
hdfs dfs -ls "${HIVE_EXT}"
hdfs dfs -ls "${HIVE_LAB}"
```

You should see no tables yet in `HIVE_EXT`, and `landing` in `HIVE_LAB`.

**Check question:** Which component knows that a table named `landisgyr_csv` exists — HDFS or the Metastore? Where is the data?

Optional: run the same statements in **Hue → Editor → Hive** (see [the Hue section above](#optional--use-hue-instead-of-beeline-and-hdfs)).

---

## 1. External table over a CSV copy

**Goal:** Create an external table, copy a smart-meter CSV into its folder, and query it.

An external table is a table definition on top of files that you manage yourself. Hive reads **every file in the table's folder**. Without a `LOCATION` clause that folder is created for you under `HIVE_EXT`, named like the table. (Choosing your own location comes in a later lab.)

Define the table. Hive maps CSV fields **by position**, not by header name — so you can choose your own column names. Timestamps stay `STRING` for now (section 2 shows why), and the header line is skipped with a table property:

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
TBLPROPERTIES ('skip.header.line.count'='1');
```

Switch to the second terminal. Hive has created the table folder — it is empty. Copy the CSV from the shared workshop data into it:

```bash
hdfs dfs -ls "${HIVE_EXT}"
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_csv/"
hdfs dfs -ls "${HIVE_EXT}/landisgyr_csv"
```

Query the table. The first statement only reads the file; the second needs a real job (watch the Tez progress in Beeline):

```sql
SELECT * FROM landisgyr_csv LIMIT 5;
SELECT COUNT(*) FROM landisgyr_csv;
```

Inspect what the Metastore stored. Look for `Table Type`, `Location`, and the serde/format lines:

```sql
DESCRIBE FORMATTED landisgyr_csv;
SHOW CREATE TABLE landisgyr_csv;
```

You should see `EXTERNAL_TABLE` and a location that is the `landisgyr_csv` folder you just copied the file into.

The table **is** the folder. Drop a second file into it, and query again without telling Hive anything:

```bash
hdfs dfs -cp "${HIVE_EXT}/landisgyr_csv/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_csv/second-copy.csv"
```

```sql
SELECT COUNT(*) FROM landisgyr_csv;
```

The count doubles. Remove the extra file and count again:

```bash
hdfs dfs -rm -skipTrash "${HIVE_EXT}/landisgyr_csv/second-copy.csv"
```

```sql
SELECT COUNT(*) FROM landisgyr_csv;
```

**Check question:** Nobody ran a load command, yet new rows appeared. What does that mean for a pipeline that lands files into a folder that a table already points at?

---

## 2. Schema on read — and what DROP does

**Goal:** See what Hive does when the table definition does not match the file, and what `DROP TABLE` does to external data.

Define a second table with wrong types: a timestamp that is not in Hive's format, and a number column that contains `L1`/`L2`/`L3`. It also declares only five of the fourteen columns. Copy the CSV into its folder, like in section 1, and query it:

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
TBLPROPERTIES ('skip.header.line.count'='1');
```

```bash
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_wrong/"
```

```sql
SELECT * FROM landisgyr_wrong LIMIT 5;
```

You should get no error, but `NULL` in every column whose type does not fit. Hive checks types when it **reads**, not when you create the table, and a failed conversion becomes `NULL`.

Now drop that table and check the files:

```sql
DROP TABLE landisgyr_wrong;
SHOW TABLES;
```

```bash
hdfs dfs -ls "${HIVE_EXT}"
hdfs dfs -ls "${HIVE_EXT}/landisgyr_wrong"
```

The table is gone, but the folder and the CSV are still on HDFS: dropping an **external** table removes only the metadata. Remove the leftover folder yourself:

```bash
hdfs dfs -rm -r -skipTrash "${HIVE_EXT}/landisgyr_wrong"
```

**Dropping the data with the table.** Sometimes an external table should clean up after itself, for example a scratch table. The table property `external.table.purge` makes `DROP TABLE` delete the files as well. Create a table like `landisgyr_csv`, set the property, and put a CSV into its folder:

```sql
CREATE EXTERNAL TABLE landisgyr_purge LIKE landisgyr_csv;
ALTER TABLE landisgyr_purge SET TBLPROPERTIES ('external.table.purge'='true');
SHOW TBLPROPERTIES landisgyr_purge;
```

```bash
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_purge/"
hdfs dfs -ls "${HIVE_EXT}/landisgyr_purge"
```

```sql
SELECT COUNT(*) FROM landisgyr_purge;
DROP TABLE landisgyr_purge;
```

```bash
hdfs dfs -ls "${HIVE_EXT}"
```

This time the `landisgyr_purge` folder is gone together with the table (it may end up in your HDFS trash, as in the HDFS lab). Your other tables are untouched.

**Check question:** A nightly job reads a column as `INT`, but the source system starts sending `1.5`. What does Hive do — and how would you notice? When would you set `external.table.purge`, and when would it be dangerous?

---

## 3. Partitions — ADD PARTITION and MSCK REPAIR

**Goal:** Build a partitioned external table over folders that arrive from outside, and teach Hive about each partition.

A **partition** is a sub-folder named `column=value`. Hive reads only the folders a query needs. Look at the prepared landing area — one folder per station — and at one file in it:

```bash
hdfs dfs -ls -R "${HIVE_LAB}/landing/landisgyr_by_station"
hdfs dfs -cat "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-101/*" | head -3
```

Compare the rows with the original CSV: the `station_id` column is gone. In a partitioned table the value lives in the **folder name**, not in the file.

Define the table first. `station_id` is declared in `PARTITIONED BY`, not in the column list. Recent CDP versions can discover new folders in the background; the property below switches that off so you can see the manual steps:

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
TBLPROPERTIES ('discover.partitions'='false');
```

Now copy **only one** station into the table folder, and query:

```bash
hdfs dfs -cp "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-101" "${HIVE_EXT}/landisgyr_by_station/"
hdfs dfs -ls -R "${HIVE_EXT}/landisgyr_by_station"
```

```sql
SHOW PARTITIONS landisgyr_by_station;
SELECT COUNT(*) FROM landisgyr_by_station;
```

The folder holds data, but you should see no partitions and a count of `0`. The files exist on HDFS; the Metastore does not know about them yet. Register the partition. Without a `LOCATION` clause Hive uses the folder `station_id=TS-101` inside the table folder — exactly where you copied the files:

```sql
ALTER TABLE landisgyr_by_station ADD PARTITION (station_id='TS-101');

SHOW PARTITIONS landisgyr_by_station;
SELECT station_id, COUNT(*) FROM landisgyr_by_station GROUP BY station_id;
```

Two more stations arrive. Copy them into the table folder and query again:

```bash
hdfs dfs -cp "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-204" "${HIVE_EXT}/landisgyr_by_station/"
hdfs dfs -cp "${HIVE_LAB}/landing/landisgyr_by_station/station_id=TS-305" "${HIVE_EXT}/landisgyr_by_station/"
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

Fifteen rows are too few to see any difference. Build the data in two steps. First a CSV table with jittered copies of the meter rows (15 × 1000 = 15,000 rows):

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
STORED AS TEXTFILE;

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

Now the ORC and Parquet versions. Instead of writing out the column list again, use **CTAS** (`CREATE TABLE AS SELECT`): the new table takes its columns and types from the query, and Hive writes the query result in the file format you name — create and load in one statement. Both tables are filled from `meter_csv`, so every format holds identical data:

```sql
CREATE EXTERNAL TABLE meter_orc STORED AS ORC AS
SELECT * FROM meter_csv;

CREATE EXTERNAL TABLE meter_parquet STORED AS PARQUET AS
SELECT * FROM meter_csv;
```

Look at what CTAS derived from the query. The column names and types match `meter_csv`, but the storage section is different:

```sql
SHOW CREATE TABLE meter_orc;
DESCRIBE FORMATTED meter_parquet;
```

You should see `EXTERNAL_TABLE`, the same ten columns, and ORC or Parquet input/output formats instead of the text format.

Check the row counts, then switch to the second terminal. Compare how much space each format needs, and list the files Hive wrote:

```sql
SELECT 'csv', COUNT(*) FROM meter_csv
UNION ALL SELECT 'orc', COUNT(*) FROM meter_orc
UNION ALL SELECT 'parquet', COUNT(*) FROM meter_parquet;
```

```bash
hdfs dfs -du -h "${HIVE_EXT}"
hdfs dfs -ls "${HIVE_EXT}/meter_csv" "${HIVE_EXT}/meter_orc" "${HIVE_EXT}/meter_parquet"
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

**Check question:** CTAS gave you ORC and Parquet tables in one statement. Which parts of the table definition did Hive take from the query, and which did you have to say yourself? Why are `event_code` and `comm_status` almost free in ORC while `current_a` is not? Which format would you pick for a curated table that analysts query by a few columns — and why would you keep the CSV only in the landing area?

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
hdfs dfs -ls "${HIVE_EXT}/meter_orc"
```

The count doubled and there is a second file. `INSERT INTO` **appends**. Replace the table content instead:

```sql
INSERT OVERWRITE TABLE meter_orc SELECT * FROM meter_csv;
SELECT COUNT(*) FROM meter_orc;
```

```bash
hdfs dfs -ls "${HIVE_EXT}/meter_orc"
```

You should be back at 15,000 rows with a single file.

**Check question:** An hourly job uses `INSERT INTO` and fails halfway, then the scheduler restarts it. What does the table look like afterwards?

**Where to go from here:** `INSERT OVERWRITE` fixes the retry problem for a whole table. Changing or deleting *single rows* in external tables safely (overwrite one partition, rewrite it, drop it, merge by rewriting) takes more work, and it is the reason lakehouse table formats exist. You try both ways side by side in the [lakehouse module](../../07-lakehouse-iceberg/README.md). Next in this lab: **managed** tables, where Hive does the row-level work for you.

---

## 6. Managed tables

**Goal:** Create a managed table and find out what is different from an external one — location, ownership, and transactions.

A **managed** table belongs to Hive: Hive decides where the files go, and `DROP TABLE` deletes them. In CDP, managed tables are **transactional** (ACID) ORC tables by default. Create one from your CSV table (CTAS, as in section 4 — this time without `EXTERNAL`):

```sql
CREATE TABLE landisgyr_managed AS
SELECT * FROM landisgyr_csv;

SELECT COUNT(*) FROM landisgyr_managed;
DESCRIBE FORMATTED landisgyr_managed;
```

In the `DESCRIBE` output compare with section 1: `Table Type`, `Location` (the managed warehouse, not your folder), the `InputFormat`, and in `Table Parameters` the entries `transactional` and `transactional_properties`.

Try to look at the files in the second terminal. `HIVE_MANAGED` should match the `Location` from the `DESCRIBE` output — compare the two and adjust the variable if your cluster differs:

```bash
hdfs dfs -ls -R "${HIVE_MANAGED}/landisgyr_managed"
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

## 7. UPDATE, DELETE, MERGE on managed tables

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

Both statements work. HDFS files are still immutable, so Hive does not edit them: each change writes a small **delta** folder, and readers merge the deltas on the fly. If you can read the table location (section 6), list it again and look for `delta_…` and `delete_delta_…` folders:

```bash
hdfs dfs -ls -R "${HIVE_MANAGED}/landisgyr_managed"
```

Many small changes mean many deltas, so Hive **compacts** them in the background. Ask for a compaction and watch its state:

```sql
SHOW COMPACTIONS;
ALTER TABLE landisgyr_managed COMPACT 'major';
SHOW COMPACTIONS;
```

Now a correction file arrives for `TS-101`: one corrected reading (`08:45`) and one new reading (`09:15`). First create an external table for it. `LIKE` copies the column definitions and settings of `landisgyr_csv` — including the skipped header line, so the file you create next needs a header too:

```sql
CREATE EXTERNAL TABLE landisgyr_changes LIKE landisgyr_csv;
```

Create the file locally, with a header like the original CSV, and put it into the folder of the new table:

```bash
cat > "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" <<'EOF'
timestamp,station_id,device_id,phase,active_power_kw,reactive_power_kvar,voltage_v,current_a,power_factor,frequency_hz,transformer_load_pct,quality_flag,event_code,comm_status
2026-01-15T08:45:00Z,TS-101,LG-TS-101-A,L1,203.9,38.8,229.0,318.0,0.980,49.99,68.9,OK,,ONLINE
2026-01-15T09:15:00Z,TS-101,LG-TS-101-A,L1,199.5,38.1,229.6,313.0,0.981,50.00,67.4,OK,,ONLINE
EOF
hdfs dfs -put -f "/tmp/landisgyr-changes.csv.${WORKSHOP_USER}" "${HIVE_EXT}/landisgyr_changes/"
```

```sql
SELECT * FROM landisgyr_changes;
```

Apply the file with a real `MERGE`: update the row that exists, insert the row that does not. The match condition is the key of a reading (station + timestamp):

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

## 8. SQL basics — filter, aggregate, CASE, NULL, views

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

## 9. Joins

**Goal:** Combine meter readings with reference data in one basic join.

The station coordinates and districts live in a separate reference file. Create an external table for it. As in section 1, the table gets an empty folder under `HIVE_EXT`; you fill it in the second terminal after the `CREATE` statement:

```sql
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
```

Copy the shared CSV into the table folder and check that the table returns rows. `-f` overwrites the file if it is already there, so you can repeat the step:

```bash
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv" "${HIVE_EXT}/stations/"
```

```sql
SELECT * FROM stations;
```

**Inner join.** Add the district to each station's peak load. Rows without a match on either side disappear:

```sql
SELECT s.municipality, s.district, m.station_id, MAX(m.transformer_load_pct) AS max_load_pct
FROM landisgyr_v m
JOIN stations s ON m.station_id = s.station_id
GROUP BY s.municipality, s.district, m.station_id
ORDER BY max_load_pct DESC;
```

You should get one row per station. `landisgyr_v` is the view from section 8; Hive runs the join as a Tez job, like every other query in this lab.

**Check question:** Imagine `stations` listed only two of the three stations. What would the result above show for the third one, and how could you notice that readings are missing from a report built on this join? (Left joins, anti-joins, and joins that multiply rows are in the [advanced Hive lab](../../10-advanced-hive/lab/lab_advanced_hive.md).)

---

## 10. Statistics — what the optimizer knows

**Goal:** Collect table and column statistics, and see how they change what Hive knows about your data.

Hive plans a query before it runs it. For a good plan (how many reducers, which join strategy) the optimizer needs to know how big the data is. That knowledge is **statistics** in the Metastore: row counts and sizes per table, and per column the number of distinct values, `NULL`s, minimum, and maximum. Files that you copied into an external table folder yourself (section 1) have no statistics yet. Check the table parameters and look for `numRows` and `totalSize`:

```sql
DESCRIBE FORMATTED landisgyr_csv;
```

Now ask for the plan of an aggregation. Look for `Tez`, the vertices `Map 1` and `Reducer 2`, and the `Statistics:` line of the table scan, which shows what Hive assumes about the table:

```sql
EXPLAIN
SELECT station_id, MAX(transformer_load_pct) FROM landisgyr_csv GROUP BY station_id;
```

Collect table statistics. This runs a job that reads the data once. Then look at the table parameters again:

```sql
ANALYZE TABLE landisgyr_csv COMPUTE STATISTICS;
DESCRIBE FORMATTED landisgyr_csv;
```

You should see `numRows` with the number of readings and `totalSize` with the size of the file. Run the `EXPLAIN` from above again and compare the `Statistics:` line: Hive now knows the row count instead of guessing from the file size.

Column statistics are collected separately. They tell the optimizer how selective a filter or a join key is:

```sql
ANALYZE TABLE landisgyr_csv COMPUTE STATISTICS FOR COLUMNS;
DESCRIBE FORMATTED landisgyr_csv station_id;
DESCRIBE FORMATTED landisgyr_csv transformer_load_pct;
```

The output has one row of numbers per column: `min`, `max`, `num_nulls`, `distinct_count`, and for text columns the average and maximum length. You should see three distinct values for `station_id` and a minimum and maximum for the load.

With accurate table statistics Hive can answer some queries from the Metastore alone. Run the count that needed a Tez job in section 1 again and watch Beeline:

```sql
SELECT COUNT(*) FROM landisgyr_csv;
```

For a partitioned table, statistics are kept per partition. Collect them for all partitions of the table from section 3 and look at one of them:

```sql
ANALYZE TABLE landisgyr_by_station PARTITION (station_id) COMPUTE STATISTICS;
DESCRIBE FORMATTED landisgyr_by_station PARTITION (station_id='TS-101');
```

**Check question:** A new file lands in the folder of `landisgyr_csv` and nobody runs `ANALYZE TABLE` again. What does `numRows` say, and what could go wrong when the optimizer trusts it? Which tables would you analyze regularly in a pipeline?

---

## Stretch (optional)

Run SQL non-interactively. Save a statement with a variable to a file and run it with `beeline -f` from the second terminal — the same way a scheduled job would:

```bash
cat > "/tmp/station-summary.sql.${WORKSHOP_USER}" <<'EOF'
USE ${ws_user};
SELECT station_id, COUNT(*) AS readings FROM meter_orc WHERE station_id = '${station}' GROUP BY station_id;
EOF
beeline --hivevar ws_user="${WORKSHOP_USER}" --hivevar station=TS-305 \
  -f "/tmp/station-summary.sql.${WORKSHOP_USER}"
```

- Join three ways: `landisgyr_v` + `stations` + the OpenStreetMap context (a new external table for `${WORKSHOP_ROOT}/data/openstreetmap`, copied the same way as in section 9; filter `buffer_m = 250`) to relate peak load to the share of industrial area.  
- Schema change on an external table: `ALTER TABLE landisgyr_csv ADD COLUMNS (note STRING);` — what do old rows show? Does the CSV change?  
- Parquet footer with a proper tool: `parquet-tools meta "<parquet-file>"` (if it is on your `PATH`).  
- Clean up: `DROP DATABASE ${ws_user} CASCADE;` and then list `${HIVE_EXT}` and the warehouse folder of your managed tables (`DESCRIBE DATABASE` shows both) — which data is gone, which is still there?  
- Hue: run one of the join queries in the Hive editor and open the query in **Job Browser**.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket and your table folders under `HIVE_EXT`):

```bash
./04-basics-hive/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
