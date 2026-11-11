# Spark hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need one terminal on the edge node for `pyspark3` and `spark-submit`, a second one for `yarn` commands, and optionally a third for `beeline` in section 12.

The lab has two clearly separated parts:

| Part | Sections | Tool | Language | Style |
|------|----------|------|----------|-------|
| **A. Interactive** | 0–10 | `pyspark3` | Python | You type, Spark answers immediately |
| **B. Batch** | 11 onward | `spark-submit` | Script file (PySpark) | You hand over a finished program and walk away |

Part A starts **very slowly**: first plain Python variables, then tiny DataFrames built by hand (no files, no HDFS). Only from section 6 on do we read real CSV files.

**No shell on the edge node?** Sections 0–10 of Part A also run from a Jupyter notebook on your laptop through Livy and `sparkmagic`: [notebooks/spark_lab_sparkmagic.ipynb](notebooks/spark_lab_sparkmagic.ipynb). Set up Jupyter as in [module 09, section 6](../../09-basics-livy/lab/lab_basics_livy.md). The notebook writes the same `spark-curated` folder, so `check.sh` works for both ways. Part B (`spark-submit`) always runs on the edge node.

Set your Kerberos identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`. `SPARK_LAB` holds the shared batch script on HDFS. The three `*_CSV` paths point at workshop sample data under `${WORKSHOP_ROOT}/data`.

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
```

The `kinit` asks for your password, so it has its own block. Then set the rest:

```bash
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export WORKSHOP_HOME="/user/${WORKSHOP_USER}"   # your HDFS home; any folder you may write to works
export SPARK_LAB="${WORKSHOP_ROOT}/06-spark"
export HADOOP_CONF_DIR=/etc/hadoop/conf   # must be set before pyspark3 / spark-submit, otherwise the shell prints many warnings
export METER_CSV="${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv"
export WEATHER_CSV="${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"
export AWATTAR_CSV="${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"
```

**Spark** runs distributed transforms: the **driver** plans work, **executors** run tasks in parallel on YARN **containers**. Input and output stay on **HDFS** — same storage pattern as MapReduce, Tez, and Hive. This lab reads landing CSVs, builds a small **curated** Parquet dataset in your home directory, and optionally registers it in the **Hive Metastore** for SQL engines.

---

# Part A — Interactive work with `pyspark3` (Python)

## What is `pyspark3`?

`pyspark3` is an **interactive Python shell** (a REPL: read–eval–print loop) with Spark already wired in. When it starts it:

1. launches a Spark **driver** — here on your edge node, as a process attached to your terminal;
2. asks YARN for **executors** (containers) when the first job needs them;
3. creates two ready-made objects for you:
   - `spark` — the `SparkSession`, the entry point for creating DataFrames and running SQL;
   - `sc` — the `SparkContext`, the lower-level handle (app name, master, configuration).

You type a Python statement, press Enter, and the result is printed immediately. Nothing is saved: when you exit, the session and everything you defined in it is gone (only files you **write** to HDFS survive).

Use `pyspark3` for **exploration**: looking at data, trying a transformation, checking a schema. It is the wrong tool for anything that must run unattended or repeatedly — that is what `spark-submit` is for (Part B).

Useful shell habits:

- The prompt is `>>>`; a continuation line shows `...`. Inside brackets `( )` you can split a statement over several lines; **do not leave empty lines** inside such a block.
- Typing a variable name alone prints its value.
- `exit()` or Ctrl-D leaves the shell.
- Up-arrow recalls earlier lines.

---

## 0. Orient — start `pyspark3`

**Goal:** Start an interactive Spark session and find your application in the cluster.

No `--master` option is needed: the environment already points Spark to YARN.

```bash
pyspark3 --name "spark-lab-${WORKSHOP_USER}"
```

Wait for the `>>>` prompt, then confirm the app name, master and version:

```python
spark.sparkContext.appName
spark.sparkContext.master
spark.version
```

Leave this shell open for sections 1–10. In a **second** terminal (same user, valid ticket), list running Spark applications:

```bash
yarn application -list -appStates RUNNING -appTypes SPARK
```

You should see your shell session as a running application. In the ResourceManager UI (URL from your handout), open the application link and note the **Spark UI** proxy URL — stages and tasks appear there while you run actions later in the lab.

**Check question:** `pyspark3` defaults to **client** deploy mode on YARN. Where does the driver run — on your edge node or inside a container? (Why can an interactive shell not run its driver in the cluster?)

---

## 1. Warm-up — plain Python variables

**Goal:** Get comfortable with the prompt before touching Spark. This is ordinary Python; Spark is not involved yet.

```python
station = "TS-101"
station
```

```python
power_kw = 42.5
load_pct = 63
station, power_kw, load_pct
```

Do a calculation and print a sentence:

```python
power_w = power_kw * 1000
print(f"{station} delivers {power_w} W")
```

A **list** holds several values, a **tuple** is a fixed group, and a **dictionary** maps names to values:

```python
powers = [42.5, 39.0, 51.2]
sum(powers) / len(powers)
```

```python
reading = ("TS-101", 42.5)
reading[0]
```

```python
reading_dict = {"station_id": "TS-101", "active_power_kw": 42.5}
reading_dict["active_power_kw"]
```

A list of tuples already looks like a small table — this is what we turn into a Spark DataFrame next:

```python
rows = [
    ("TS-101", 42.5, 63),
    ("TS-102", 39.0, 58),
    ("TS-103", 51.2, 71),
]
rows
```

**Check question:** Where does the variable `rows` live — on HDFS, in an executor, or in the driver's memory?

---

## 2. Your first DataFrame — built by hand

**Goal:** Turn the Python list into a Spark DataFrame, without reading any file.

A **DataFrame** is a table with named, typed columns. Spark spreads its rows over **partitions** so executors can process them in parallel. Create one from the `rows` list and give the columns names:

```python
df = spark.createDataFrame(rows, ["station_id", "active_power_kw", "load_pct"])
df
```

The shell only shows the column names and types. To see data, call an **action**:

```python
df.show()
```

Look at the structure Spark inferred from the Python values:

```python
df.printSchema()
df.columns
df.dtypes
```

Count the rows and fetch them back into Python:

```python
df.count()
df.collect()
```

`collect()` brings **all** rows into the driver as a Python list. That is fine for 3 rows and dangerous for 3 billion — prefer `show()`, `take(2)` or `limit(10)` on real data.

Instead of letting Spark guess, you can state the schema yourself (a string of `name TYPE` pairs):

```python
df2 = spark.createDataFrame(
    [("TS-101", 42.5, 63), ("TS-102", 39.0, 58)],
    "station_id STRING, active_power_kw DOUBLE, load_pct INT")
df2.printSchema()
df2.show()
```

**Check question:** Which of `show`, `printSchema`, `count`, `collect` are actions that make Spark do work, and which only inspect metadata?

---

## 3. Select, filter, add columns — still tiny data

**Goal:** Learn the basic DataFrame verbs on the 3-row table.

Import the column helper functions once. The alias `F` is a common convention:

```python
from pyspark.sql import functions as F
```

**Select** columns and **filter** rows:

```python
df.select("station_id", "load_pct").show()
df.filter(F.col("load_pct") > 60).show()
```

**Add** a column with `withColumn`, and give it a readable name with `alias`/`withColumnRenamed`:

```python
df_kw = df.withColumn("active_power_w", F.col("active_power_kw") * 1000)
df_kw.show()
```

Use a condition to create a label:

```python
df_flag = df.withColumn(
    "status", F.when(F.col("load_pct") >= 70, "HIGH").otherwise("NORMAL"))
df_flag.show()
```

Sort the result:

```python
df_flag.orderBy(F.col("active_power_kw").desc()).show()
```

Every call returns a **new** DataFrame; `df` itself never changes. Check it:

```python
df.show()
```

**Lazy evaluation:** `df_kw = ...` printed nothing and ran no job. Only `show()`, `count()`, `collect()` or `write` trigger work. Spark records the recipe first, then optimizes it. Peek at the recipe:

```python
df_flag.explain()
```

**Check question:** If you chain ten `filter` calls but never call `show` or `count`, does YARN start executors for them?

---

## 4. Aggregate — groupBy and SQL on a tiny table

**Goal:** Summarize values per group, first with the DataFrame API and then with SQL.

Build a slightly larger hand-made table with several readings per station:

```python
tiny = spark.createDataFrame(
    [("TS-101", "08:00", 42.5), ("TS-101", "08:15", 44.0),
     ("TS-102", "08:00", 39.0), ("TS-102", "08:15", 41.5),
     ("TS-103", "08:00", 51.2), ("TS-103", "08:15", 49.8)],
    ["station_id", "time", "active_power_kw"])
tiny.show()
```

Average, maximum and number of readings per station:

```python
(tiny.groupBy("station_id")
     .agg(F.avg("active_power_kw").alias("avg_kw"),
          F.max("active_power_kw").alias("max_kw"),
          F.count(F.lit(1)).alias("n"))
     .orderBy("station_id")
     .show())
```

Register the DataFrame as a **temp view** and ask the same question in SQL — both paths use the same engine and produce the same plan:

```python
tiny.createOrReplaceTempView("tiny_readings")
spark.sql("""
SELECT station_id,
       AVG(active_power_kw) AS avg_kw,
       MAX(active_power_kw) AS max_kw,
       COUNT(*)             AS n
FROM tiny_readings
GROUP BY station_id
ORDER BY station_id
""").show()
```

You should see three rows (`TS-101`, `TS-102`, `TS-103`) with `n = 2`.

**Check question:** Why is a temp view gone after you exit the shell, and does it write anything to the Metastore?

---

## 5. Join — two tiny tables

**Goal:** Combine two DataFrames on a common column.

A second hand-made table with station names:

```python
names = spark.createDataFrame(
    [("TS-101", "Nord"), ("TS-102", "Süd"), ("TS-104", "West")],
    ["station_id", "region"])
names.show()
```

An **inner** join keeps only stations present in both tables; a **left** join keeps all stations from the left table and fills missing values with `null`:

```python
df.join(names, "station_id", "inner").show()
df.join(names, "station_id", "left").show()
```

Predict the output before you run it: which station is missing from the inner join? Which `region` is `null` in the left join? What happened to `TS-104`?

**Check question:** What changes if you swap the two tables in the left join?

---

## 6. Read CSV — schema on read

**Goal:** Now use real files: load smart-meter and operator weather CSVs from HDFS and inspect types.

The shell inherits the exports of the terminal that started it. Pull paths and your username into Python once:

```python
import os
workshop_user = os.environ["WORKSHOP_USER"]
workshop_home = os.environ["WORKSHOP_HOME"]
meter_csv     = os.environ["METER_CSV"]
weather_csv   = os.environ["WEATHER_CSV"]
awattar_csv   = os.environ["AWATTAR_CSV"]
```

Read the meter file with a header and inferred types (small data — inference is fine here):

```python
meter_raw = spark.read.option("header", True).option("inferSchema", True).csv(meter_csv)
meter_raw.printSchema()
meter_raw.show(5, False)
meter_raw.count()
```

The first column is the reading time; the CSV header calls it `timestamp`. For production pipelines you prefer an explicit schema (just like in section 2) so a bad row cannot widen a column type. Spark maps CSV fields **by position** when you supply a schema — name the first field `ts_utc` even though the header says `timestamp`:

```python
meter = (spark.read.option("header", True)
    .schema(
        "ts_utc STRING, station_id STRING, device_id STRING, phase STRING, "
        "active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE, "
        "current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE, "
        "transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, "
        "comm_status STRING")
    .csv(meter_csv)
    .withColumn("ts_utc", F.to_timestamp(F.col("ts_utc"))))
meter.count()
```

Load weather the same way (two operator stations, 15-minute steps):

```python
weather = (spark.read.option("header", True)
    .schema(
        "ts_utc STRING, weather_station_id STRING, station_name STRING, "
        "temperature_c DOUBLE, relative_humidity_pct INT, wind_speed_mps DOUBLE, "
        "precipitation_mm DOUBLE, pressure_hpa DOUBLE, weather_quality STRING")
    .csv(weather_csv)
    .withColumn("ts_utc", F.to_timestamp(F.col("ts_utc"))))
weather.count()
```

You should see **15** meter rows and **10** weather rows (header excluded).

**Check question:** Why is explicit schema safer than `inferSchema=True` on a large landing folder?

---

## 7. Cleanse — filters and lazy evaluation

**Goal:** Keep quality-approved readings, normalize empty event codes, and see how actions trigger work.

Same verbs as in section 3, now on real data. Note that the assignment returns instantly without launching any job:

```python
meter_ok = (meter.filter(F.col("quality_flag") == "OK")
    .withColumn("event_code",
        F.when(F.trim(F.col("event_code")) == "", F.lit(None)).otherwise(F.col("event_code")))
    .dropDuplicates(["ts_utc", "station_id", "device_id", "phase"]))
```

```python
rejected = meter.count() - meter_ok.count()
print(f"rejected_rows={rejected}")
meter_ok.count()
```

You should see **3** rejected rows (WARN quality flags in the sample) and **12** cleansed rows. Watch the Spark UI — the first `count()` on `meter_ok` schedules a new job.

---

## 8. Aggregate — DataFrame API and Spark SQL

**Goal:** Summarize average power and peak load per transformer station and hour (same pattern as section 4).

```python
hourly = (meter_ok
    .withColumn("hour_utc", F.date_trunc("hour", F.col("ts_utc")))
    .groupBy("station_id", "hour_utc")
    .agg(F.avg("active_power_kw").alias("avg_power_kw"),
         F.max("transformer_load_pct").alias("max_load_pct"),
         F.count(F.lit(1)).alias("reading_count"))
    .orderBy("station_id", "hour_utc"))
hourly.show(truncate=False)
```

Register a temp view and express the same logic in SQL:

```python
meter_ok.createOrReplaceTempView("meter_ok")
spark.sql("""
SELECT station_id,
       date_trunc('hour', ts_utc) AS hour_utc,
       AVG(active_power_kw) AS avg_power_kw,
       MAX(transformer_load_pct) AS max_load_pct,
       COUNT(*) AS reading_count
FROM meter_ok
GROUP BY station_id, date_trunc('hour', ts_utc)
ORDER BY station_id, hour_utc
""").show(truncate=False)
```

You should see two hour buckets (08:00 and 09:00 UTC) for each of the three transformer stations.

---

## 9. Join — align timestamps

**Goal:** Attach operator weather to each meter reading at the same 15-minute timestamp, and add hourly market prices.

The sample weather stations (`GRID-WS-01`, `GRID-WS-02`) differ from transformer IDs (`TS-101`, …) — you join on **time** only, so each meter row matches **both** weather stations at that timestamp:

```python
joined = meter_ok.join(weather, ["ts_utc"], "inner")
joined.count()
```

You should get **24** rows (12 meter × 2 weather stations per timestamp). Try a **left** join and compare:

```python
meter_ok.join(weather, ["ts_utc"], "left").count()
```

Add hourly **awattar** prices by truncating meter time to the hour:

```python
prices = (spark.read.option("header", True)
    .schema(
        "price_start STRING, price_end STRING, market STRING, "
        "price_eur_mwh DOUBLE, price_ct_kwh DOUBLE, currency STRING")
    .csv(awattar_csv)
    .withColumn("price_hour", F.date_trunc("hour", F.to_timestamp(F.col("price_start")))))
curated = (joined
    .withColumn("price_hour", F.date_trunc("hour", F.col("ts_utc")))
    .join(prices.select("price_hour", "price_eur_mwh", "market"), ["price_hour"], "left")
    .drop("price_hour"))
curated.show(5, False)
```

**Check question:** With an inner join on time only, why does one meter timestamp produce two output rows?

---

## 10. Write Parquet — curated layer on HDFS

**Goal:** Persist the joined dataset as partitioned Parquet under your HDFS home.

```python
out_interactive = f"{workshop_home}/spark-curated"
curated.write.mode("overwrite").partitionBy("station_id").parquet(out_interactive)
```

Exit the shell (`exit()` or Ctrl-D) and inspect the layout from bash:

```bash
hdfs dfs -ls "${WORKSHOP_HOME}/spark-curated"
hdfs dfs -ls "${WORKSHOP_HOME}/spark-curated/station_id=TS-101"
hdfs dfs -du -s -h "${WORKSHOP_HOME}/spark-curated"
```

You should see `_SUCCESS`, one directory per `station_id`, and Parquet part files inside. This is your **curated** layer: columnar files ready for Hive, Impala, or the next Spark job — landing CSVs stay untouched under `${WORKSHOP_ROOT}/data`.

Notice what is **gone**: your `meter`, `curated`, … variables lived only in the shell session. Only the Parquet files remain. To repeat this work tomorrow you would have to retype it — which leads to Part B.

---

# Part B — Batch work with `spark-submit`

> **Clear cut: from here on you leave the shell.** Everything above was typed interactively into `pyspark3`. From now on you do **not** type Spark code at a prompt. You submit a finished program from the bash command line.

## What does `spark-submit` do?

`spark-submit` is the command that **launches a packaged Spark application** on a cluster. You give it:

- **what to run** — a script (`.py`) or a JAR (Scala/Java) plus its arguments;
- **how to run it** — `--deploy-mode`, resources such as `--executor-memory`, `--num-executors`, and a `--name`.

(The cluster manager is already preconfigured to YARN in this environment, so `--master` is not needed.)

It then asks YARN to start the application, ships your code to the cluster, runs it from start to finish, and the application **ends by itself**. There is no prompt and no session to keep open.

| | `pyspark3` | `spark-submit` |
|---|---|---|
| Purpose | Explore, prototype | Production / scheduled / repeatable runs |
| Interaction | Type, get results immediately | None; runs unattended to completion |
| Code lives in | Your head / terminal history | A file under version control (here on HDFS) |
| Language here | Python | Any: the lab script is PySpark; a Scala app would be a JAR |
| Session objects | `spark`, `sc` pre-created | Your program creates its own `SparkSession` |
| Typical deploy mode | `client` (driver on edge node) | `cluster` (driver in a YARN container) |
| Output | Printed in terminal | Written to HDFS / tables; logs via `yarn logs` |
| Lifetime | Until you exit | Until the script finishes |

The pipeline is the same one you just built by hand: read CSV, cleanse, join, write Parquet. The difference is only **how it is run**. Schedulers (Oozie, Airflow, cron) always use `spark-submit`.

---

## 11. Batch — spark-submit on YARN

**Goal:** Run the same pipeline as a batch job with the shared script on HDFS.

Make sure you are in a normal bash prompt (not `>>>`). Admin setup placed `spark_cleanse_join.py` under `${SPARK_LAB}/assets/`. Submit in **cluster** mode so the driver runs in YARN (logs via `yarn logs`, as in the YARN basics lab):

```bash
spark-submit --deploy-mode cluster \
  --name "spark-batch-${WORKSHOP_USER}" \
  "hdfs://${SPARK_LAB}/assets/spark_cleanse_join.py" \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "${WORKSHOP_HOME}/spark-batch-curated"
```

Note how the command ends: the four trailing values are **arguments to the script** (three inputs, one output path), replacing the `os.environ` lookups and hard-coded paths you used in the shell.

**Optional:** submit the script from local disk — copy it first, because a path without a scheme is read only on the node where you run `spark-submit`:

```bash
hdfs dfs -get "${SPARK_LAB}/assets/spark_cleanse_join.py" /tmp/spark_cleanse_join.py
spark-submit --deploy-mode cluster \
  --name "spark-batch-local-${WORKSHOP_USER}" \
  /tmp/spark_cleanse_join.py \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "${WORKSHOP_HOME}/spark-batch-curated-local"
```

When the application state is `FINISHED`, confirm output:

```bash
hdfs dfs -ls "${WORKSHOP_HOME}/spark-batch-curated"
yarn application -list -appStates FINISHED -appTypes SPARK | tail -5
```

You should see `_SUCCESS` under `spark-batch-curated` with the same row count (**24**) as section 9.

**Check question:** What does `spark-submit` return to your terminal when the job runs in cluster mode, and where do you find the job's `print`/log output?

---

## 12. Relate — register Parquet in the Metastore

**Goal:** Save your curated Parquet as a table in the Metastore so SQL engines can query it.

This is interactive work again, so go back to `pyspark3` (or use `spark-sql` if your handout recommends it):

```bash
pyspark3 --name "spark-metastore-${WORKSHOP_USER}"
```

```python
import os
workshop_user = os.environ["WORKSHOP_USER"]
workshop_home = os.environ["WORKSHOP_HOME"]
batch_path = f"{workshop_home}/spark-batch-curated"
```

Create your personal database and save the batch output as a table. There is no `LOCATION` clause: Spark writes the table files into the default external warehouse folder of your database.

```python
spark.sql(f"CREATE DATABASE IF NOT EXISTS {workshop_user}")
spark.sql(f"USE {workshop_user}")
spark.read.parquet(batch_path).write.mode("overwrite").format("parquet").saveAsTable("spark_curated_join")
spark.sql("SELECT COUNT(*) AS rows, COUNT(DISTINCT station_id) AS stations FROM spark_curated_join").show()
spark.sql("DESCRIBE FORMATTED spark_curated_join").show(50, False)
```

You should see **24** rows and **3** stations. **Optional cross-check** in Beeline (second terminal):

```bash
beeline -e "
USE ${WORKSHOP_USER};
SELECT station_id, COUNT(*) AS n FROM spark_curated_join GROUP BY station_id ORDER BY station_id;
"
```

Hive and Impala read the same Metastore entry. In the `DESCRIBE FORMATTED` output, find the `Location`: it sits under the default external warehouse folder of `<your_user>`, not under `/user/...`. The batch Parquet in `${WORKSHOP_HOME}/spark-batch-curated` stays untouched (managed table semantics are covered in the Hive basics module).

---

## 13. Optional — failure signals on YARN

**Goal:** Provoke three common failures and read the signal in the shell or YARN logs.

**Wrong input path** (in `pyspark3`) — expect `AnalysisException` or `Path does not exist`:

```python
spark.read.csv("/no/such/workshop/path").count()
```

**Output path already exists** (in `pyspark3`) — reload the batch output and write again without `overwrite`:

```python
import os
wh = os.environ["WORKSHOP_HOME"]
again = spark.read.parquet(f"{wh}/spark-batch-curated")
again.write.parquet(f"{wh}/spark-batch-curated")
```

**Executor memory too small** (from bash, `spark-submit`) — submit the batch script with an unrealistically tiny executor heap (may stay `ACCEPTED` or fail with `Container killed`):

```bash
spark-submit --deploy-mode cluster \
  --executor-memory 64m \
  --name "spark-oom-demo-${WORKSHOP_USER}" \
  "hdfs://${SPARK_LAB}/assets/spark_cleanse_join.py" \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "${WORKSHOP_HOME}/spark-oom-demo"
```

Find the application id and skim logs:

```bash
yarn application -list -appStates FAILED,FINISHED,KILLED -appTypes SPARK | tail -3
yarn logs -applicationId "<application-id>" | tail -40
```

---

## 14. Spark UI, YARN logs, pi and the event log

**Goal:** Run a small compute job in cluster mode, read its Spark UI / History Server data while and after it runs, and find its logs and event log on the cluster.

Create a pi estimator. It runs in several rounds with a short pause, so the application stays alive for about 2–3 minutes and you can watch it:

```bash
vim /tmp/pi_lab.py
```

Content of the file:

```python
import random, time
from operator import add
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("pi_lab").enableHiveSupport().getOrCreate()
n = 4_000_000
total = 0
rounds = 5
for i in range(rounds):
    total += (spark.sparkContext.parallelize(range(n), 8)
        .map(lambda _: 1 if random.random() ** 2 + random.random() ** 2 <= 1 else 0)
        .reduce(add))
    time.sleep(20)
print(f"Pi is roughly {4.0 * total / (n * rounds)}")
spark.stop()
```

Run it in cluster mode:

```bash
spark-submit --deploy-mode cluster --name "spark-pi-${WORKSHOP_USER}" /tmp/pi_lab.py
```

While the application is `RUNNING` (second terminal), find it and open its Spark UI from the ResourceManager UI. Also open the Spark History Server and enable **Show incomplete applications**.

```bash
yarn application -list -appStates RUNNING -appTypes SPARK
```

After the first rounds, answer from the Spark UI (job numbers start at 0 per application):

1. What is the **maximum execution time of a task** in job 0 → stage 0? (Stage page → Summary Metrics → Duration → Max)
2. How many **stages** are there in job 0?
3. How many **tasks** ran in job 0?
4. How many **tasks ran per executor**? (Stage page → Aggregated Metrics by Executor)

When the application is `FINISHED`, note its application id and continue:

5. What is the **total uptime** of the application? (History Server, or `yarn application -status <application-id>`)
6. Can you retrieve the logs with `yarn logs -applicationId <application-id>`? Why does this only work after the application has finished (log aggregation)?
7. Find the **value of pi** in the driver stdout:

   ```bash
   yarn logs -applicationId <application-id> -log_files stdout | grep "Pi is roughly"
   ```

8. Find and download the **Spark event log** from HDFS and view its JSON content. The directory is set in `spark.eventLog.dir`:

   ```bash
   grep eventLog /etc/spark3/conf/spark-defaults.conf
   hdfs dfs -ls <eventLog-dir> | grep <application-id>
   hdfs dfs -get <eventLog-dir>/<application-id>* /tmp/
   head -3 /tmp/<application-id>* | python3 -m json.tool
   ```

   Which event types do you see (`SparkListenerApplicationStart`, `SparkListenerJobStart`, `SparkListenerTaskEnd`, …)? The History Server rebuilds the UI from this file.

**Check question:** The driver ran in a YARN container in cluster mode. Why did `spark-submit` not print the value of pi in your terminal?

---

## Stretch (optional)

- In `pyspark3`, repartition `curated` to 1 file per station with `repartition(1, "station_id")` before write; compare part-file counts with section 10.  
- Run `curated.explain(True)` and discuss shuffle stages (look for `Exchange`).  
- `cache()` `meter_ok`, run two aggregations, and compare timings in the Spark UI storage tab.

---

## Self-check

From the repo on the edge node:

```bash
./06-basics-spark/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
