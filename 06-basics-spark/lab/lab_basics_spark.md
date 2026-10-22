# Spark hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need one terminal on the edge node for `spark-shell` and `spark-submit`, a second one for `yarn` commands, and optionally a third for `beeline` in section 7.

The lab has two clearly separated parts:

| Part | Sections | Tool | Language | Style |
|------|----------|------|----------|-------|
| **A. Interactive** | 0–5 | `spark-shell` | Scala | You type, Spark answers immediately |
| **B. Batch** | 6 onward | `spark-submit` | Script file (PySpark) | You hand over a finished program and walk away |

Set your Kerberos identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`. `SPARK_LAB` holds the shared batch script on HDFS. The three `*_CSV` paths point at workshop sample data under `${WORKSHOP_ROOT}/data`. `HS2_URL` is the HiveServer2 JDBC URL from your handout (section 7 only).

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export SPARK_LAB="${WORKSHOP_ROOT}/06-spark"
export METER_CSV="${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
export WEATHER_CSV="${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"
export AWATTAR_CSV="${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv"
export HS2_URL="<jdbc-url-from-your-handout>"
```

**Spark** runs distributed transforms: the **driver** plans work, **executors** run tasks in parallel on YARN **containers**. Input and output stay on **HDFS** — same storage pattern as MapReduce, Tez, and Hive. This lab reads landing CSVs, builds a small **curated** Parquet dataset in your home directory, and optionally registers it in the **Hive Metastore** for SQL engines.

---

# Part A — Interactive work with `spark-shell` (Scala)

## What is `spark-shell`?

`spark-shell` is an **interactive Scala REPL** (read–eval–print loop) with Spark already wired in. When it starts it:

1. launches a Spark **driver** — here on your edge node, as a process attached to your terminal;
2. asks YARN for **executors** (containers) when the first job needs them;
3. creates two ready-made objects for you:
   - `spark` — the `SparkSession`, the entry point for reading data and running SQL;
   - `sc` — the `SparkContext`, the lower-level handle (app name, master, configuration).

You type a Scala expression, press Enter, and the result is printed immediately. Nothing is saved: when you exit, the session and everything you defined in it is gone (only files you **write** to HDFS survive).

Use `spark-shell` for **exploration**: looking at data, trying a transformation, checking a schema. It is the wrong tool for anything that must run unattended or repeatedly — that is what `spark-submit` is for (Part B).

Useful shell habits:

- `:help` lists REPL commands, `:paste` lets you paste multi-line code (finish with Ctrl-D), `:quit` or Ctrl-D exits.
- The prompt is `scala>`. Results are echoed as `res0: ...` or `name: Type = ...`.

---

## 0. Orient — start `spark-shell` on YARN

**Goal:** Start an interactive Spark session backed by YARN and find your application in the cluster.

Start the shell with YARN as the cluster manager (use `spark3-shell` from your handout if your cluster names it differently):

```bash
spark-shell --master yarn --name "spark-lab-${WORKSHOP_USER}"
```

Wait for the `scala>` prompt, then confirm the app name and master:

```scala
spark.sparkContext.appName
spark.sparkContext.master
spark.version
```

Leave this shell open for sections 1–5. In a **second** terminal (same user, valid ticket), list running Spark applications:

```bash
yarn application -list -appStates RUNNING -appTypes SPARK
```

You should see your shell session as a running application. In the ResourceManager UI (URL from your handout), open the application link and note the **Spark UI** proxy URL — stages and tasks appear there while you run actions in section 2.

**Check question:** `spark-shell` defaults to **client** deploy mode on YARN. Where does the driver run — on your edge node or inside a container? (Why can an interactive shell not run its driver in the cluster?)

---

## 1. Read CSV — schema on read

**Goal:** Load smart-meter and operator weather CSVs from HDFS and inspect types.

The shell inherits the exports of the terminal that started it. Pull paths and your username into Scala once, and import the SQL functions:

```scala
import org.apache.spark.sql.functions._

val workshopUser = sys.env("WORKSHOP_USER")
val meterCsv     = sys.env("METER_CSV")
val weatherCsv   = sys.env("WEATHER_CSV")
val awattarCsv   = sys.env("AWATTAR_CSV")
```

Read the meter file with a header and inferred types (small data — inference is fine here):

```scala
val meterRaw = spark.read.option("header", true).option("inferSchema", true).csv(meterCsv)
meterRaw.printSchema()
meterRaw.show(5, false)
meterRaw.count()
```

The first column is the reading time; the CSV header calls it `timestamp`. For production pipelines you prefer an explicit schema so a bad row cannot widen a column type. Spark maps CSV fields **by position** when you supply a schema — name the first field `ts_utc` even though the header says `timestamp`:

```scala
val meter = spark.read.option("header", true)
  .schema(
    "ts_utc STRING, station_id STRING, device_id STRING, phase STRING, " +
    "active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE, " +
    "current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE, " +
    "transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, " +
    "comm_status STRING")
  .csv(meterCsv)
  .withColumn("ts_utc", to_timestamp(col("ts_utc")))
meter.count()
```

Load weather the same way (two operator stations, 15-minute steps):

```scala
val weather = spark.read.option("header", true)
  .schema(
    "ts_utc STRING, weather_station_id STRING, station_name STRING, " +
    "temperature_c DOUBLE, relative_humidity_pct INT, wind_speed_mps DOUBLE, " +
    "precipitation_mm DOUBLE, pressure_hpa DOUBLE, weather_quality STRING")
  .csv(weatherCsv)
  .withColumn("ts_utc", to_timestamp(col("ts_utc")))
weather.count()
```

You should see **15** meter rows and **10** weather rows (header excluded).

**Check question:** Why is explicit schema safer than `inferSchema=true` on a large landing folder?

---

## 2. Cleanse — filters and lazy evaluation

**Goal:** Keep quality-approved readings, normalize null event codes, and see how actions trigger work.

Transformations are **lazy** until an **action** (`count`, `show`, `write`) runs. Note that the shell prints the `val` definition instantly without launching any job:

```scala
val meterOk = meter.filter(col("quality_flag") === "OK")
  .withColumn("event_code",
    when(trim(col("event_code")) === "", lit(null)).otherwise(col("event_code")))
  .dropDuplicates("ts_utc", "station_id", "device_id", "phase")

val rejected = meter.count() - meterOk.count()
println(s"rejected_rows=$rejected")
meterOk.count()
```

You should see **3** rejected rows (WARN quality flags in the sample) and **12** cleansed rows. Watch the Spark UI — the first `count()` on `meterOk` schedules a new job.

**Check question:** If you chain ten `filter` calls but never call `count`, does YARN start executors?

---

## 3. Aggregate — DataFrame API and Spark SQL

**Goal:** Summarize average power and peak load per transformer station and hour.

```scala
val hourly = meterOk
  .withColumn("hour_utc", date_trunc("hour", col("ts_utc")))
  .groupBy("station_id", "hour_utc")
  .agg(
    avg("active_power_kw").alias("avg_power_kw"),
    max("transformer_load_pct").alias("max_load_pct"),
    count(lit(1)).alias("reading_count"))
  .orderBy("station_id", "hour_utc")
hourly.show(false)
```

Register a temp view and express the same logic in SQL:

```scala
meterOk.createOrReplaceTempView("meter_ok")
spark.sql("""
SELECT station_id,
       date_trunc('hour', ts_utc) AS hour_utc,
       AVG(active_power_kw) AS avg_power_kw,
       MAX(transformer_load_pct) AS max_load_pct,
       COUNT(*) AS reading_count
FROM meter_ok
GROUP BY station_id, date_trunc('hour', ts_utc)
ORDER BY station_id, hour_utc
""").show(false)
```

You should see two hour buckets (08:00 and 09:00 UTC) for each of the three transformer stations.

---

## 4. Join — align timestamps

**Goal:** Attach operator weather to each meter reading at the same 15-minute timestamp, and add hourly market prices.

The sample weather stations (`GRID-WS-01`, `GRID-WS-02`) differ from transformer IDs (`TS-101`, …) — you join on **time** only, so each meter row matches **both** weather stations at that timestamp:

```scala
val joined = meterOk.join(weather, Seq("ts_utc"), "inner")
joined.count()
```

You should get **24** rows (12 meter × 2 weather stations per timestamp). Try a **left** join and compare:

```scala
meterOk.join(weather, Seq("ts_utc"), "left").count()
```

Add hourly **awattar** prices by truncating meter time to the hour:

```scala
val prices = spark.read.option("header", true)
  .schema(
    "price_start STRING, price_end STRING, market STRING, " +
    "price_eur_mwh DOUBLE, price_ct_kwh DOUBLE, currency STRING")
  .csv(awattarCsv)
  .withColumn("price_hour", date_trunc("hour", to_timestamp(col("price_start"))))

val curated = joined
  .withColumn("price_hour", date_trunc("hour", col("ts_utc")))
  .join(prices.select("price_hour", "price_eur_mwh", "market"), Seq("price_hour"), "left")
  .drop("price_hour")
curated.show(5, false)
```

**Check question:** With an inner join on time only, why does one meter timestamp produce two output rows?

---

## 5. Write Parquet — curated layer on HDFS

**Goal:** Persist the joined dataset as partitioned Parquet under your HDFS home.

```scala
val outInteractive = s"/user/$workshopUser/spark-curated"
curated.write.mode("overwrite").partitionBy("station_id").parquet(outInteractive)
```

Exit the shell (`:quit` or Ctrl-D) and inspect the layout from bash:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/spark-curated"
hdfs dfs -ls "/user/${WORKSHOP_USER}/spark-curated/station_id=TS-101"
hdfs dfs -du -s -h "/user/${WORKSHOP_USER}/spark-curated"
```

You should see `_SUCCESS`, one directory per `station_id`, and Parquet part files inside. This is your **curated** layer: columnar files ready for Hive, Impala, or the next Spark job — landing CSVs stay untouched under `${WORKSHOP_ROOT}/data`.

Notice what is **gone**: your `meter`, `curated`, … values lived only in the shell session. Only the Parquet files remain. To repeat this work tomorrow you would have to retype it — which leads to Part B.

---

# ✂️ Part B — Batch work with `spark-submit`

> **Clear cut: from here on you leave the shell.** Everything above was typed interactively into `spark-shell`. From now on you do **not** type Spark code at a prompt. You submit a finished program from the bash command line.

## What does `spark-submit` do?

`spark-submit` is the command that **launches a packaged Spark application** on a cluster. You give it:

- **what to run** — a script (`.py`) or a JAR (Scala/Java) plus its arguments;
- **where to run it** — `--master yarn`;
- **how to run it** — `--deploy-mode`, resources such as `--executor-memory`, `--num-executors`, and a `--name`.

It then asks YARN to start the application, ships your code to the cluster, runs it from start to finish, and the application **ends by itself**. There is no prompt and no session to keep open.

| | `spark-shell` | `spark-submit` |
|---|---|---|
| Purpose | Explore, prototype | Production / scheduled / repeatable runs |
| Interaction | Type, get results immediately | None; runs unattended to completion |
| Code lives in | Your head / terminal history | A file under version control (here on HDFS) |
| Language here | Scala | Any: the lab script is PySpark; a Scala app would be a JAR |
| Session objects | `spark`, `sc` pre-created | Your program creates its own `SparkSession` |
| Typical deploy mode | `client` (driver on edge node) | `cluster` (driver in a YARN container) |
| Output | Printed in terminal | Written to HDFS / tables; logs via `yarn logs` |
| Lifetime | Until you exit | Until the script finishes |

The pipeline is the same one you just built by hand: read CSV, cleanse, join, write Parquet. The difference is only **how it is run**. Schedulers (Oozie, Airflow, cron) always use `spark-submit`.

---

## 6. Batch — spark-submit on YARN

**Goal:** Run the same pipeline as a batch job with the shared script on HDFS.

Make sure you are in a normal bash prompt (not `scala>`). Admin setup placed `spark_cleanse_join.py` under `${SPARK_LAB}/assets/`. Submit in **cluster** mode so the driver runs in YARN (logs via `yarn logs`, as in the YARN basics lab):

```bash
spark-submit --master yarn --deploy-mode cluster \
  --name "spark-batch-${WORKSHOP_USER}" \
  "hdfs://${SPARK_LAB}/assets/spark_cleanse_join.py" \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "/user/${WORKSHOP_USER}/spark-batch-curated"
```

Note how the command ends: the four trailing values are **arguments to the script** (three inputs, one output path), replacing the `sys.env` lookups and hard-coded paths you used in the shell.

**Optional:** submit the script from local disk — copy it first, because a path without a scheme is read only on the node where you run `spark-submit`:

```bash
hdfs dfs -get "${SPARK_LAB}/assets/spark_cleanse_join.py" /tmp/spark_cleanse_join.py
spark-submit --master yarn --deploy-mode cluster \
  --name "spark-batch-local-${WORKSHOP_USER}" \
  /tmp/spark_cleanse_join.py \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "/user/${WORKSHOP_USER}/spark-batch-curated-local"
```

When the application state is `FINISHED`, confirm output:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/spark-batch-curated"
yarn application -list -appStates FINISHED -appTypes SPARK | tail -5
```

You should see `_SUCCESS` under `spark-batch-curated` with the same row count (**24**) as section 4.

**Check question:** What does `spark-submit` return to your terminal when the job runs in cluster mode, and where do you find the job's `println`/log output?

---

## 7. Relate — register Parquet in the Metastore

**Goal:** Save your curated Parquet as a table in the Metastore so SQL engines can query it.

This is interactive work again, so go back to `spark-shell` (or use `spark-sql` with the same `--master yarn` if your handout recommends it):

```bash
spark-shell --master yarn --name "spark-metastore-${WORKSHOP_USER}"
```

```scala
val workshopUser = sys.env("WORKSHOP_USER")
val batchPath = s"/user/$workshopUser/spark-batch-curated"
```

Create your personal database and save the batch output as a table. There is no `LOCATION` clause: Spark writes the table files into the default external warehouse folder of your database.

```scala
spark.sql(s"CREATE DATABASE IF NOT EXISTS ws_$workshopUser")
spark.sql(s"USE ws_$workshopUser")

spark.read.parquet(batchPath)
  .write.mode("overwrite").format("parquet").saveAsTable("spark_curated_join")
spark.sql("SELECT COUNT(*) AS rows, COUNT(DISTINCT station_id) AS stations FROM spark_curated_join").show()
spark.sql("DESCRIBE FORMATTED spark_curated_join").show(50, false)
```

You should see **24** rows and **3** stations. **Optional cross-check** in Beeline (second terminal):

```bash
beeline -u "${HS2_URL}" -e "
USE ws_${WORKSHOP_USER};
SELECT station_id, COUNT(*) AS n FROM spark_curated_join GROUP BY station_id ORDER BY station_id;
"
```

Hive and Impala read the same Metastore entry. In the `DESCRIBE FORMATTED` output, find the `Location`: it sits under the default external warehouse folder of `ws_<your_user>`, not under `/user/...`. The batch Parquet in `/user/${WORKSHOP_USER}/spark-batch-curated` stays untouched (managed table semantics are covered in the Hive basics module).

---

## 8. Optional — failure signals on YARN

**Goal:** Provoke three common failures and read the signal in the shell or YARN logs.

**Wrong input path** (in `spark-shell`) — expect `AnalysisException` or `Path does not exist`:

```scala
spark.read.csv("/no/such/workshop/path").count()
```

**Output path already exists** (in `spark-shell`) — reload the batch output and write again without `overwrite`:

```scala
val u = sys.env("WORKSHOP_USER")
val again = spark.read.parquet(s"/user/$u/spark-batch-curated")
again.write.parquet(s"/user/$u/spark-batch-curated")
```

**Executor memory too small** (from bash, `spark-submit`) — submit the batch script with an unrealistically tiny executor heap (may stay `ACCEPTED` or fail with `Container killed`):

```bash
spark-submit --master yarn --deploy-mode cluster \
  --executor-memory 64m \
  --name "spark-oom-demo-${WORKSHOP_USER}" \
  "hdfs://${SPARK_LAB}/assets/spark_cleanse_join.py" \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "/user/${WORKSHOP_USER}/spark-oom-demo"
```

Find the application id and skim logs:

```bash
yarn application -list -appStates FAILED,FINISHED,KILLED -appTypes SPARK | tail -3
yarn logs -applicationId "<application-id>" | tail -40
```

---

## Stretch (optional)

- In `spark-shell`, repartition `curated` to 1 file per station with `repartition(1, col("station_id"))` before write; compare part-file counts with section 5.  
- Run `curated.explain(true)` before the join and discuss shuffle stages.  
- `cache()` `meterOk`, run two aggregations, and compare timings in the Spark UI storage tab.

---

## Self-check

From the repo on the edge node:

```bash
./06-basics-spark/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
