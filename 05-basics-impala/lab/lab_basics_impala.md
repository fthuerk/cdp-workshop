# Impala hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. This lab is **Hue-based**: run all SQL in **Hue → Editor → Impala** (and **Editor → Hive** in sections 4 and 5); URL from your handout. Use one terminal on the edge node only for `hdfs` commands, a single `impala-shell` example (section 0) and a Python `impyla` example (section 7). Your personal database has the same name as your user (`WORKSHOP_USER`). Where the SQL shows `<your_user>`, type your user name; in Hue you can also select the database in the drop-down.

Set your Kerberos identity and paths once in the terminal. `WORKSHOP_USER` is the short name you use with `kinit`. `IMPALA_LAB` holds shared module files on HDFS (including a scaled smart-meter CSV for timing). `IMPALA_EXT` is the default external warehouse folder of your database: you never set a table location in this lab — the engine creates a folder per table below `IMPALA_EXT`, and you copy files into it. `IMPALA_OPTS` holds the `impala-shell` connection options (used by the one shell example and the self-check) (HiveServer2 over HTTP on port 28000, Kerberos, TLS).

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export IMPALA_LAB="${WORKSHOP_ROOT}/05-impala"
export IMPALA_EXT="/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db"   # adjust if needed
export IMPALA_OPTS="-i <impala-host>:28000 --protocol=hs2-http -d default -k --ssl --ca_cert=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem"
```

Replace `<impala-host>` with the Impala coordinator host from your handout. The `impala-shell` call in section 0 and the self-check use these options.

**Impala** and **Hive** share the **Hive Metastore**: table names, columns, and HDFS locations are the same catalog. Impala daemons read files directly and return results with low latency; Hive compiles most queries into **Tez** jobs on YARN (as in the YARN basics module). This lab builds its own database and external table — nothing from other modules is required.

---

## 0. Orient — connect and create your database

**Goal:** Open an Impala session and create a personal database in the shared Metastore.

In **Hue → Editor → Impala**, replace `<your_user>` with your user name and run:

```sql
CREATE DATABASE IF NOT EXISTS <your_user>;
USE <your_user>;
SELECT current_database(), user();
```

You should see your database name and your user name in the result.

**Impala shell (the one shell example):** the same query from the terminal, with the connection options from the intro:

```bash
impala-shell ${IMPALA_OPTS} -d ${WORKSHOP_USER} -q "SELECT current_database(), user();"
```

**Check question:** If Hive and Impala both list `<your_user>`, where is that definition stored — in HDFS or in the Metastore?

---

## 1. External table over scaled meter data

**Goal:** Register an external table Impala can query and copy workshop CSV data into its default folder.

Define the table in the Hue Impala editor. Column names are yours; Hive and Impala map CSV fields **by position**. The header line is skipped with a table property. There is no `LOCATION` clause: the table folder is `${IMPALA_EXT}/impala_meter`.

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS impala_meter (
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

Admin setup placed a **15,000-row** smart-meter file under `${IMPALA_LAB}/scaled/` (many copies of the small sample — enough rows to feel a speed difference). Copy it into the table folder (terminal), then tell Impala that files arrived (Hue):

```bash
hdfs dfs -mkdir -p "${IMPALA_EXT}/impala_meter"
hdfs dfs -cp -f "${IMPALA_LAB}/scaled/meter-15k.csv" "${IMPALA_EXT}/impala_meter/"
hdfs dfs -ls -h "${IMPALA_EXT}/impala_meter"
```

```sql
REFRESH impala_meter;
```

Sanity checks:

```sql
DESCRIBE FORMATTED impala_meter;
SELECT * FROM impala_meter LIMIT 5;
SELECT COUNT(*) FROM impala_meter;
```

You should see `EXTERNAL=TRUE`, a location under your `IMPALA_EXT` folder, and **15,000** rows.

**Check question:** Who owns the CSV bytes in HDFS — Impala or the table definition in the Metastore?

---

## 2. Interactive analytics in Impala

**Goal:** Run aggregations the way an analyst exploring grid load would — and notice how fast Impala returns.

Impala is aimed at **read-heavy, interactive SQL** on data already in HDFS. Try a grouped summary by transformer station:

```sql
SELECT station_id,
       COUNT(*) AS readings,
       ROUND(AVG(active_power_kw), 1) AS avg_kw,
       MAX(transformer_load_pct) AS peak_load_pct
FROM impala_meter
GROUP BY station_id
ORDER BY station_id;
```

Filter to quality warnings and rank the highest load:

```sql
SELECT ts_utc, station_id, active_power_kw, transformer_load_pct, quality_flag
FROM impala_meter
WHERE quality_flag = 'WARN'
ORDER BY transformer_load_pct DESC
LIMIT 10;
```

You should get a small result set in seconds, with no MapReduce-style progress lines.

**Check question:** Would you run this exploration on the raw landing CSV or on a curated ORC/Parquet table in production — and why?

---

## 3. Table statistics — COMPUTE STATS

**Goal:** Give the Impala planner row counts and column statistics, and see the difference in `SHOW` output and the query plan.

Impala picks join order and memory estimates from statistics stored in the Metastore. A new external table has none. Check:

```sql
SHOW TABLE STATS impala_meter;
SHOW COLUMN STATS impala_meter;
EXPLAIN SELECT station_id, COUNT(*) FROM impala_meter GROUP BY station_id;
```

You should see `#Rows = -1` (unknown), `-1` distinct values per column, and `cardinality=unavailable` in the plan.

Compute the statistics (Impala scans the table once):

```sql
COMPUTE STATS impala_meter;
```

Check again:

```sql
SHOW TABLE STATS impala_meter;
SHOW COLUMN STATS impala_meter;
EXPLAIN SELECT station_id, COUNT(*) FROM impala_meter GROUP BY station_id;
```

Now `#Rows` should be **15,000**, `#Distinct Values` is filled in for each column, and the plan shows a real `cardinality=`.

Statistics do **not** update themselves when files change. After new data lands (as in section 6), re-run `COMPUTE STATS`; for big tables use `COMPUTE INCREMENTAL STATS` on partitioned tables, or `COMPUTE STATS ... TABLESAMPLE` to save time.

**Hive comparison:** Hive keeps its own statistics in the same Metastore (`ANALYZE TABLE ... COMPUTE STATISTICS [FOR COLUMNS]`, see the Hive lab). Use `COMPUTE STATS` for Impala planning; do not assume Hive-gathered statistics are enough.

**Check question:** Which statement tells you whether the planner has row counts for a table — and what value means "unknown"?

---

## 4. Same query in Impala and Hive — speed

**Goal:** Run one heavy scan twice and compare wall-clock time and what happens on YARN.

Use the same aggregation in both engines:

```sql
SELECT station_id, COUNT(*), AVG(active_power_kw), MAX(transformer_load_pct)
FROM impala_meter
GROUP BY station_id
ORDER BY station_id;
```

Run it in **Hue → Editor → Impala** and note the execution time Hue shows under the result. Then run the identical statement in **Hue → Editor → Hive** (select your database first). The first Hive statement in a session often pays a **Tez startup** cost; that is normal.

While Hive runs, Hue shows Tez progress in the query log. When it finishes, list YARN applications for your user in the terminal:

```bash
yarn application -list -appStates FINISHED,RUNNING | grep "${WORKSHOP_USER}" | head -5
```

You should see a **Tez** application for the Hive query and **no** comparable batch job for the Impala run (Impala executes inside its daemons). On most clusters Impala finishes noticeably faster for this scan; exact seconds depend on load and hardware.

**Check question:** Hive is still the right tool for some jobs in the same Metastore. Name one kind of work you would keep on Hive rather than Impala.

---

## 5. Row-level UPDATE and DELETE — errors on Hive tables

**Goal:** See that neither Impala nor Hive can patch rows in place on this **external** table, and read the error messages.

An operator asks you to mark every `WARN` reading as reviewed. Try an update in the **Hue Impala editor** first:

```sql
UPDATE impala_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
```

Impala should reject the statement (wording varies by version). Typical themes: **updates are not supported** on this table type, or only **Kudu** tables allow row-level changes.

Try a delete:

```sql
DELETE FROM impala_meter WHERE station_id = 'TS-305';
```

Same story — external HDFS files are **immutable**; engines append new files or rewrite partitions instead of editing bytes in place.

Switch to **Hue → Editor → Hive** (same database) and run the same two statements:

```sql
UPDATE impala_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM impala_meter WHERE station_id = 'TS-305';
```

Hive should fail with an error that the table is **not transactional** (often `SemanticException` / `GTUD`). That is expected: this table is **external** and not **ACID**. Row-level change needs a **managed transactional** table (Hive) or **Kudu** (Impala updates), plus overwrite/merge patterns for file-based pipelines.

**Check question:** Why is “fix one bad row in the CSV” the wrong mental model for data on HDFS?

---

## 6. New file on disk — refresh metadata

**Goal:** See that Impala (and Hive) trust the Metastore until you tell them files changed.

Append another copy of the data file without changing the table DDL:

```bash
hdfs dfs -cp -f "${IMPALA_EXT}/impala_meter/meter-15k.csv" "${IMPALA_EXT}/impala_meter/extra-copy.csv"
```

In the Hue Impala editor, count rows — you may still see **15,000** until metadata catches up:

```sql
SELECT COUNT(*) FROM impala_meter;
INVALIDATE METADATA impala_meter;
SELECT COUNT(*) FROM impala_meter;
```

After `INVALIDATE METADATA`, the count should jump to **30,000** (two identical files). Hive sees the same files once its metadata is refreshed (`MSCK REPAIR` is for partitions; for a non-partitioned external table, `REFRESH impala_meter` in Impala and a new Hive session or `REFRESH` in Hive 3+ applies — if `REFRESH` is unavailable in your Hive version, run `SELECT COUNT(*)` again after a minute or reconnect Beeline).

Remove the extra file so the self-check stays predictable:

```bash
hdfs dfs -rm -f "${IMPALA_EXT}/impala_meter/extra-copy.csv"
```

In the Hue Impala editor:

```sql
INVALIDATE METADATA impala_meter;
SELECT COUNT(*) FROM impala_meter;
```

You should be back at **15,000** rows.

**Check question:** Who is responsible in a pipeline when a landing job adds files — the writer, or every SQL user running `INVALIDATE METADATA`?

---

## 7. Python with impyla

**Goal:** Query Impala from a Python script using the same Kerberos/HTTP/TLS connection as the shell.

Install the client once (in a virtualenv, if you like) and make sure your `kinit` ticket is valid:

```bash
pip install --user impyla kerberos thrift_sasl
```

Save as `impyla_meter.py`:

```python
import os
from impala.dbapi import connect

user = os.environ["WORKSHOP_USER"]

conn = connect(
    host=os.environ.get("IMPALA_HOST", "<impala-host>"),   # coordinator from your handout
    port=28000,
    database=f"{user}",
    use_http_transport=True,
    http_path="cliservice",
    use_ssl=True,
    ca_cert="/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem",
    auth_mechanism="GSSAPI",          # Kerberos ticket from kinit
)

cur = conn.cursor()
cur.execute("""
    SELECT station_id, COUNT(*) AS readings, ROUND(AVG(active_power_kw), 1) AS avg_kw
    FROM impala_meter
    GROUP BY station_id
    ORDER BY station_id
""")
for station_id, readings, avg_kw in cur.fetchall():
    print(f"{station_id}: {readings} readings, avg {avg_kw} kW")

cur.close()
conn.close()
```

Run it:

```bash
IMPALA_HOST=<impala-host> python3 impyla_meter.py
```

You should see one line per station, matching the Hue result from section 2.

**Check question:** Which ticket does `impyla` use to authenticate — a password in the script, or your `kinit` ticket?

---

## Stretch (optional)

- `EXPLAIN` the aggregation in Impala and compare with `EXPLAIN` in Hive — notice Impala’s plan without YARN stages.  
- Create a tiny **managed transactional** table in Hive (`TBLPROPERTIES ('transactional'='true')`), insert a few rows, `UPDATE` one row successfully in Hive, then try the same `UPDATE` in Impala and compare errors.

---

## Self-check

From the repo root on the edge node (export `IMPALA_OPTS` as in the intro):

```bash
./05-basics-impala/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
