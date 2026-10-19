# Impala hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need **two terminals** on the edge node: one for `impala-shell` and one for `beeline` (Hive) in section 4 only.

Set your Kerberos identity and paths once in **both** terminals. `WORKSHOP_USER` is the short name you use with `kinit`. `IMPALA_LAB` holds shared module files on HDFS (including a scaled smart-meter CSV for timing). `IMPALA_WORK` is your folder for table data. `IMPALA_OPTS` is how you reach the Impala coordinator (from your handout). `HS2_URL` is the HiveServer2 JDBC URL (same handout — only for the Hive comparison in section 4).

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export IMPALA_LAB="${WORKSHOP_ROOT}/05-impala"
export IMPALA_WORK="${IMPALA_LAB}/work/${WORKSHOP_USER}"
export IMPALA_OPTS="<impala-shell-options-from-handout>"   # e.g. -i impala-host:21050
export HS2_URL="<jdbc-url-from-your-handout>"
```

**Impala** and **Hive** share the **Hive Metastore**: table names, columns, and HDFS locations are the same catalog. Impala daemons read files directly and return results with low latency; Hive compiles most queries into **Tez** jobs on YARN (as in the YARN basics module). This lab builds its own database and external table — nothing from other modules is required.

---

## 0. Orient — connect and create your database

**Goal:** Open an Impala session and create a personal database in the shared Metastore.

Create your database from the shell so `${WORKSHOP_USER}` expands correctly. If your cluster sets the coordinator in `/etc/impala/conf`, you can leave `IMPALA_OPTS` empty:

```bash
impala-shell ${IMPALA_OPTS} -q "
CREATE DATABASE IF NOT EXISTS ws_${WORKSHOP_USER};
USE ws_${WORKSHOP_USER};
SELECT current_database(), user();
"
```

Open an interactive session on that database for the rest of the lab:

```bash
impala-shell ${IMPALA_OPTS} -d ws_${WORKSHOP_USER}
```

You should see your database name and Kerberos user in the `-q` output.

Optional: run the same statements in **Hue → Editor → Impala** (URL from your handout).

**Check question:** If Hive and Impala both list `ws_<your_user>`, where is that definition stored — in HDFS or in the Metastore?

---

## 1. External table over scaled meter data

**Goal:** Copy workshop CSV data into your work folder and register an external table Impala can query.

Admin setup placed a **15,000-row** smart-meter file under `${IMPALA_LAB}/scaled/` (many copies of the small sample — enough rows to feel a speed difference). Copy it into a folder you own:

```bash
hdfs dfs -mkdir -p "${IMPALA_WORK}/meter"
hdfs dfs -cp -f "${IMPALA_LAB}/scaled/meter-15k.csv" "${IMPALA_WORK}/meter/"
hdfs dfs -ls -h "${IMPALA_WORK}/meter"
```

Define the table in Impala. Column names are yours; Hive and Impala map CSV fields **by position**. The header line is skipped with a table property. Run this from bash so the `LOCATION` uses your exported paths:

```bash
impala-shell ${IMPALA_OPTS} -d ws_${WORKSHOP_USER} -q "
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
LOCATION '${IMPALA_WORK}/meter'
TBLPROPERTIES ('skip.header.line.count'='1');
"
```

Sanity checks:

```sql
DESCRIBE FORMATTED impala_meter;
SELECT * FROM impala_meter LIMIT 5;
SELECT COUNT(*) FROM impala_meter;
```

You should see `EXTERNAL=TRUE`, a location under your `IMPALA_WORK` path, and **15,000** rows.

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

## 3. Same query in Impala and Hive — speed

**Goal:** Run one heavy scan twice and compare wall-clock time and what happens on YARN.

Use the same aggregation in both engines. In the **Impala** terminal, time one run (Impala prints elapsed time when the shell exits):

```bash
time impala-shell ${IMPALA_OPTS} -q "
USE ws_${WORKSHOP_USER};
SELECT station_id, COUNT(*), AVG(active_power_kw), MAX(transformer_load_pct)
FROM impala_meter
GROUP BY station_id
ORDER BY station_id;
"
```

In the **Hive** terminal, run the equivalent through Beeline. The first statement in a session often pays a **Tez startup** cost; that is normal:

```bash
time beeline -u "${HS2_URL}" --silent=true -e "
USE ws_${WORKSHOP_USER};
SELECT station_id, COUNT(*), AVG(active_power_kw), MAX(transformer_load_pct)
FROM impala_meter
GROUP BY station_id
ORDER BY station_id;
"
```

While Hive runs, you may see Tez vertex progress in Beeline. When it finishes, list YARN applications for your user:

```bash
yarn application -list -appStates FINISHED,RUNNING | grep "${WORKSHOP_USER}" | head -5
```

You should see a **Tez** application for the Hive query and **no** comparable batch job for the Impala run (Impala executes inside its daemons). On most clusters Impala finishes noticeably faster for this scan; exact seconds depend on load and hardware.

**Check question:** Hive is still the right tool for some jobs in the same Metastore. Name one kind of work you would keep on Hive rather than Impala.

---

## 4. Row-level UPDATE and DELETE — errors on Hive tables

**Goal:** See that neither Impala nor Hive can patch rows in place on this **external** table, and read the error messages.

An operator asks you to mark every `WARN` reading as reviewed. Try an update in **Impala** first:

```sql
UPDATE impala_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
```

Impala should reject the statement (wording varies by version). Typical themes: **updates are not supported** on this table type, or only **Kudu** tables allow row-level changes.

Try a delete:

```sql
DELETE FROM impala_meter WHERE station_id = 'TS-305';
```

Same story — external HDFS files are **immutable**; engines append new files or rewrite partitions instead of editing bytes in place.

Switch to the **Hive** terminal and open Beeline on the same database:

```bash
beeline -u "${HS2_URL}" -e "USE ws_${WORKSHOP_USER};"
```

Run the same two statements in Beeline (paste into an interactive session or use `-e`):

```sql
UPDATE impala_meter SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM impala_meter WHERE station_id = 'TS-305';
```

Hive should fail with an error that the table is **not transactional** (often `SemanticException` / `GTUD`). That is expected: this table is **external** and not **ACID**. Row-level change needs a **managed transactional** table (Hive) or **Kudu** (Impala updates), plus overwrite/merge patterns for file-based pipelines.

**Check question:** Why is “fix one bad row in the CSV” the wrong mental model for data on HDFS?

---

## 5. New file on disk — refresh metadata

**Goal:** See that Impala (and Hive) trust the Metastore until you tell them files changed.

Append another copy of the data file without changing the table DDL:

```bash
hdfs dfs -cp -f "${IMPALA_WORK}/meter/meter-15k.csv" "${IMPALA_WORK}/meter/extra-copy.csv"
```

In Impala, count rows — you may still see **15,000** until metadata catches up:

```sql
SELECT COUNT(*) FROM impala_meter;
INVALIDATE METADATA impala_meter;
SELECT COUNT(*) FROM impala_meter;
```

After `INVALIDATE METADATA`, the count should jump to **30,000** (two identical files). Hive sees the same files once its metadata is refreshed (`MSCK REPAIR` is for partitions; for a non-partitioned external table, `REFRESH impala_meter` in Impala and a new Hive session or `REFRESH` in Hive 3+ applies — if `REFRESH` is unavailable in your Hive version, run `SELECT COUNT(*)` again after a minute or reconnect Beeline).

Remove the extra file so the self-check stays predictable:

```bash
hdfs dfs -rm -f "${IMPALA_WORK}/meter/extra-copy.csv"
```

In Impala:

```sql
INVALIDATE METADATA impala_meter;
SELECT COUNT(*) FROM impala_meter;
```

You should be back at **15,000** rows.

**Check question:** Who is responsible in a pipeline when a landing job adds files — the writer, or every SQL user running `INVALIDATE METADATA`?

---

## Stretch (optional)

- Hue: run section 3’s aggregation in **Editor → Impala** and compare with **Editor → Hive**.  
- `EXPLAIN` the aggregation in Impala and compare with `EXPLAIN` in Hive — notice Impala’s plan without YARN stages.  
- Create a tiny **managed transactional** table in Hive (`TBLPROPERTIES ('transactional'='true')`), insert a few rows, `UPDATE` one row successfully in Hive, then try the same `UPDATE` in Impala and compare errors.

---

## Self-check

From the repo root on the edge node (export `IMPALA_OPTS` and `HS2_URL` as in the intro):

```bash
./05-basics-impala/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
