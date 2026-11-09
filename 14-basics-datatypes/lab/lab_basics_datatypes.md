# Data types across Hive, Impala and Spark — hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You work in **three engines side by side**: **Hue → Editor → Hive**, **Hue → Editor → Impala** (URL from your handout) and `pyspark3` in a terminal on the edge node. Open the two Hue editors in separate browser tabs and keep the terminal next to them. Your personal database has the same name as your user (`WORKSHOP_USER`). Where the SQL shows `<your_user>`, type your user name.

The idea is simple: one small table, **all columns stored as plain text**, and the same `CAST` and function calls run in each engine. You **predict** the result first, then compare. Differences are the point of this lab — they are what breaks a pipeline when a query moves from one engine to another.

Set your Kerberos identity and paths once in the terminal. `TYPES_LAB` holds the shared module file on HDFS (the raw values). `TYPES_EXT` is the default external warehouse folder of your database: you never set a table location in this lab — the engine creates a folder per table below `TYPES_EXT`, and you copy the file into it. `IMPALA_OPTS` holds the `impala-shell` connection options; only the self-check uses them (replace `<impala-host>` with the coordinator host from your handout).

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export TYPES_LAB="${WORKSHOP_ROOT}/14-datatypes"
export TYPES_EXT="/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db"   # adjust if needed

# Only used by the self-check at the end
export IMPALA_OPTS="-i <impala-host>:28000 --protocol=hs2-http -d default -k --ssl --ca_cert=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem"
```

Hive, Impala and Spark share the **Hive Metastore**, so a table is defined once and seen by all three. They do **not** share the SQL dialect: each engine has its own type system, its own cast rules and its own function library. This lab uses nothing from other modules.

---

## 0. Orient — your database and three sessions

**Goal:** Have a working session in each engine, all pointing at your database.

In **Hue → Editor → Hive**, create your database (replace `<your_user>`). The result is visible to Impala and Spark through the Metastore:

```sql
CREATE DATABASE IF NOT EXISTS <your_user>;
USE <your_user>;
SELECT current_database();
```

In **Hue → Editor → Impala**, make the new database visible and select it:

```sql
INVALIDATE METADATA;
USE <your_user>;
SELECT current_database();
```

In the terminal, start Spark and define a one-line helper `q()` that runs SQL and prints the result. The first `q()` call selects your database and shows whether Spark runs in **ANSI mode** (a stricter cast behaviour you will meet in section 2):

```bash
pyspark3 --name "types-${WORKSHOP_USER}"
```

```python
import os
db = os.environ["WORKSHOP_USER"]
q = lambda s: spark.sql(s).show(truncate=False)
q(f"USE {db}")
spark.conf.get("spark.sql.ansi.enabled")
```

You should see `'false'` for the last line on a default CDP cluster. Leave `pyspark3` open for the whole lab; type `exit()` at the end.

---

## 1. One table of raw text

**Goal:** Register a table whose columns are all `STRING`, and see the same six rows in all three engines.

Copy the shared module file into the table folder. Use a second terminal on the edge node (with the exports from the intro) so that `pyspark3` stays open:

```bash
hdfs dfs -mkdir -p "${TYPES_EXT}/edge_values"
hdfs dfs -cp -f "${TYPES_LAB}/edge/edge-values.csv" "${TYPES_EXT}/edge_values/"
hdfs dfs -cat "${TYPES_EXT}/edge_values/edge-values.csv"
```

Read the file: it is smart-meter-style raw input, but with values chosen to cause trouble — a number too large for `INT`, text instead of a number, a date that does not exist (`2026-02-30`), a local time that does not exist (`2026-03-29 02:30`, daylight saving), five spellings of "true", umlauts, and an empty field next to a field containing the word `NULL`.

In the **Hive** editor, define the table. Every column is `STRING` on purpose: the file is read as text, and each engine decides later how to turn text into numbers and timestamps:

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS edge_values (
  row_id STRING,
  raw_int STRING,
  raw_dec STRING,
  raw_ts STRING,
  raw_flag STRING,
  raw_text STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

SELECT * FROM edge_values ORDER BY row_id;
```

Now read the same table from the other two engines. In the **Impala** editor:

```sql
INVALIDATE METADATA edge_values;
SELECT * FROM edge_values ORDER BY row_id;
```

In `pyspark3`:

```python
q("SELECT * FROM edge_values ORDER BY row_id")
```

You should see **6 rows** in each engine, with identical text. Look at rows 4 and 5: the `raw_text` of row 4 is an empty string, row 5 holds the four letters `NULL`, not a real `NULL`.

**Check question:** You defined the table once, in Hive. Why do Impala and Spark see it without any further definition — and why did Impala need `INVALIDATE METADATA`?

---

## 2. Numbers — casts, overflow, decimals

**Goal:** See what each engine returns when text does not fit the target type, and which result type it picks for arithmetic.

**Predict first:** write down what you expect for rows 3 (`2147483648`), 4 (`abc`) and 6 (`0007`) before you run anything. Then run the same query in **Hive**, **Impala** and, wrapped in `q("""…""")`, in `pyspark3`:

```sql
SELECT row_id,
       CAST(raw_int AS INT)           AS as_int,
       CAST(raw_int AS TINYINT)       AS as_tinyint,
       CAST(raw_dec AS DECIMAL(10,2)) AS as_dec,
       CAST(raw_dec AS DOUBLE)        AS as_double
FROM edge_values
ORDER BY row_id;
```

In Spark the call looks like this (same SQL inside the quotes):

```python
q("""
SELECT row_id, CAST(raw_int AS INT) AS as_int, CAST(raw_int AS TINYINT) AS as_tinyint,
       CAST(raw_dec AS DECIMAL(10,2)) AS as_dec, CAST(raw_dec AS DOUBLE) AS as_double
FROM edge_values ORDER BY row_id
""")
```

Compare the three result sets column by column. Note every `NULL`, every value that changed, and every place where you got an error instead of a result. The engines do not always agree on what is "too big" or "not a number".

Decimals versus floating point matter for energy values that are summed and billed. Run this in all three engines:

```sql
SELECT CAST('0.1' AS DOUBLE) + CAST('0.2' AS DOUBLE)                  AS double_sum,
       CAST('0.1' AS DECIMAL(10,2)) + CAST('0.2' AS DECIMAL(10,2))    AS decimal_sum;
```

Finally ask each engine which **type** it gives to the result of a division. Hive has no `typeof()`, so you create a small view and describe it. Run the matching block in each engine (the view names differ so that you can compare later):

```sql
CREATE VIEW IF NOT EXISTS probe_hive AS
SELECT CAST(1 AS DECIMAL(10,2)) / CAST(3 AS DECIMAL(10,2)) AS dec_div,
       7 / 2 AS int_div;
DESCRIBE probe_hive;
```

For Impala, use the same SQL with the view name `probe_impala`. For Spark:

```python
q("""CREATE VIEW IF NOT EXISTS probe_spark AS
SELECT CAST(1 AS DECIMAL(10,2)) / CAST(3 AS DECIMAL(10,2)) AS dec_div, 7 / 2 AS int_div""")
q("DESCRIBE probe_spark")
```

Compare the `dec_div` column: precision and scale of the result type. Then compare `int_div`: does `7 / 2` give `3` or `3.5` — and what type is it?

**Check question:** A pipeline sums `DECIMAL` kWh values in Hive and the same job is later moved to Spark. Name two things that could change the total or its precision.

---

## 3. Timestamps — formats, invalid dates, time zones

**Goal:** Find out which timestamp spellings each engine accepts and whether the same text gives the same moment in time.

Timestamps are where cross-engine surprises cost the most. Predict, then run in all three engines. `UNIX_TIMESTAMP` turns the parsed value into seconds since 1970 so that you can compare engines with one number:

```sql
SELECT row_id,
       raw_ts,
       CAST(raw_ts AS TIMESTAMP)                  AS ts,
       UNIX_TIMESTAMP(CAST(raw_ts AS TIMESTAMP))  AS epoch_s
FROM edge_values
ORDER BY row_id;
```

Spark again as `q("""…""")` with the same SQL. For each engine, answer:

- Which rows are `NULL`? (rows 2, 3 and 4 use an ISO `T…Z` format, a German format and a date that does not exist)
- Does **row 1** have the **same `epoch_s`** in all three engines? If not, compare the difference with the offset of your local time zone (Vienna is UTC+1 in January).
- What happens to **row 6** (`2026-03-29 02:30:00`, a time that is skipped when clocks move forward)?

Spark exposes its session time zone. Check it and compare with what you saw:

```python
spark.conf.get("spark.sql.session.timeZone")
```

**Check question:** Your meter data arrives in UTC (`2026-01-15T08:00:00Z`). Which engine can read that text as a timestamp directly, and what would you do in the others?

---

## 4. Booleans, strings and NULL

**Goal:** See how `CAST` to `BOOLEAN` interprets different spellings and how string functions count characters.

Run in all three engines. Row 2 uses `TRUE`, row 3 `yes`, row 4 `1`, row 6 `0`:

```sql
SELECT row_id,
       raw_flag,
       CAST(raw_flag AS BOOLEAN)  AS as_bool,
       raw_text,
       LENGTH(raw_text)           AS len,
       UPPER(raw_text)            AS upper_text,
       raw_text IS NULL           AS is_null
FROM edge_values
ORDER BY row_id;
```

Look at three things:

- **Booleans:** which spellings give `true`, `false` or `NULL` — and does any engine call `yes` or `1` true?
- **Length with umlauts:** `Trafostation Süd` has 16 characters. What does `LENGTH` return in each engine, and what does `UPPER` do with `ß` in `Straße`?
- **Empty vs `NULL`:** row 4 (empty field) and row 5 (the text `NULL`) — is `is_null` true for either?

Impala also offers `UTF8_LENGTH`. Try it in the Impala editor and compare with `LENGTH`:

```sql
SELECT raw_text, LENGTH(raw_text), UTF8_LENGTH(raw_text) FROM edge_values WHERE row_id IN ('1', '6');
```

**Check question:** A validation rule says "flag must be `true` or `false`". Why is `CAST(raw_flag AS BOOLEAN) IS NOT NULL` not a safe implementation of that rule across engines?

---

## 5. Functions and UDFs — what exists where

**Goal:** Learn that the same function name does not exist, or behave the same, in every engine — and what to do when you need your own.

First list the date functions each engine ships with and compare the sizes of the lists. In the **Hive** editor, then **Impala**, then `pyspark3`:

```sql
SHOW FUNCTIONS LIKE '*date*';
```

```sql
SHOW FUNCTIONS IN _impala_builtins LIKE '*date*';
```

```python
q("SHOW FUNCTIONS LIKE '*date*'")
```

Now run each line below in **all three** engines (one statement at a time; in Spark wrap in `q("…")`). An error such as `Undefined function` or `Unknown function` is a valid result — write down ✓ or ✗ for each engine:

```sql
SELECT split('a,b,c', ',');
SELECT split_part('a,b,c', ',', 2);
SELECT date_format(CAST('2026-01-15 08:00:00' AS TIMESTAMP), 'yyyy-MM-dd');
SELECT from_timestamp(CAST('2026-01-15 08:00:00' AS TIMESTAMP), 'yyyy-MM-dd');
SELECT nvl2('a', 'b', 'c');
SELECT add_months('2026-01-31', 1);
```

When no built-in fits, you write a **user-defined function (UDF)**. In Spark the quickest way is a Python function registered for SQL. In `pyspark3`, convert kilowatts to megawatts and use it in a query:

```python
from pyspark.sql.types import DoubleType
spark.udf.register("kw_to_mw", lambda kw: None if kw is None else kw / 1000.0, DoubleType())
q("SELECT row_id, raw_dec, kw_to_mw(CAST(raw_dec AS DOUBLE)) AS mw FROM edge_values ORDER BY row_id")
```

Now call `kw_to_mw` from the **Hive** and the **Impala** editor:

```sql
SELECT kw_to_mw(1500.0);
```

You should get an error in both: a Spark UDF lives only in your Spark session. UDFs that all engines can use must be registered in the Metastore from a **JAR on HDFS** — a Java UDF in the Hive style, which Impala can load too:

| | Hive | Impala | Spark |
|---|------|--------|-------|
| Java UDF (Hive API, JAR on HDFS) | `CREATE FUNCTION … USING JAR` | `CREATE FUNCTION … LOCATION … SYMBOL` | `CREATE FUNCTION … USING JAR` |
| Native (C++) UDF/UDA | no | yes | no |
| Python UDF in the session | no | no | `spark.udf.register`, pandas UDFs |
| Visible to the other engines | via Metastore | via Metastore (own syntax) | session-only unless Hive-style |

The table is a reference; you do not create a JAR in this lab.

**Check question:** Your team needs one custom conversion function in a Hive ETL job, an Impala dashboard query and a Spark job. Which option from the table gives you a single implementation, and what do you give up compared with a Python UDF?

---

## 6. Defensive casts — find the bad rows

**Goal:** Write a check that finds unparsable values and gives the **same answer in every engine**.

Because one engine returns `NULL` where another raises an error or wraps a number, you must not rely on cast side effects. A pattern that works everywhere: a value is bad when it is present but the cast result is `NULL`. Run in all three engines:

```sql
SELECT row_id, raw_int
FROM edge_values
WHERE raw_int IS NOT NULL
  AND CAST(raw_int AS INT) IS NULL
ORDER BY row_id;
```

You should get the same rows in all three engines (the values that do not fit an `INT`). Now extend the idea yourself: write the same kind of check for `raw_dec` (decimal with scale 2) and for `raw_ts` (timestamp) and compare the lists of bad rows between engines.

---

**Stretch (optional)**

1. In `pyspark3`, run `spark.conf.set("spark.sql.ansi.enabled", "true")` and repeat the section 2 query. What changes for rows 3 and 4? Reset with `"false"`.
2. In `pyspark3`, save a Parquet table with a timestamp: `spark.sql("SELECT CAST(raw_ts AS TIMESTAMP) AS ts FROM edge_values WHERE row_id = '1'").write.mode("overwrite").saveAsTable("ts_from_spark")`. Read it from Hive and Impala. Do all three show the same hour?
3. Run `DESCRIBE probe_hive;` in Impala and `DESCRIBE probe_impala;` in Hive. Does the other engine read the view and show the same types?

**Self-check:** from the edge node run `./14-basics-datatypes/lab/check.sh` (set `IMPALA_OPTS` as in the Impala lab). If it reports `[FAIL]`, see [troubleshooting.md](troubleshooting.md).

Leave `pyspark3` with `exit()`.

---
*The generation of these labs was supported by AI.*
