# Spark hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need one terminal on the edge node for `pyspark` and `spark-submit`, and optionally a second for `beeline` in section 7.

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

## 0. Orient — PySpark on YARN

**Goal:** Start an interactive Spark session backed by YARN and find your application in the cluster.

Open PySpark with YARN as the cluster manager (use `spark3-submit` / `pyspark3` from your handout if your cluster names them differently):

```bash
pyspark --master yarn --name "spark-lab-${WORKSHOP_USER}"
```

At the `>>>` prompt, create a session handle and confirm the app name:

```python
spark.sparkContext.appName
spark.sparkContext.master
```

Leave this shell open for sections 1–5. In a **second** terminal (same user, valid ticket), list running Spark applications:

```bash
yarn application -list -appStates RUNNING -appTypes SPARK
```

You should see your PySpark app. In the ResourceManager UI (URL from your handout), open the application link and note the **Spark UI** proxy URL — stages and tasks appear there while you run actions in section 2.

**Check question:** In cluster mode on YARN, where does the driver run — on your edge node or inside a container?

---

## 1. Read CSV — schema on read

**Goal:** Load smart-meter and operator weather CSVs from HDFS and inspect types.

PySpark inherits exports from the shell that started it. Pull paths and your username into Python once:

```python
import os
from pyspark.sql import functions as F

WORKSHOP_USER = os.environ["WORKSHOP_USER"]
METER_CSV = os.environ["METER_CSV"]
WEATHER_CSV = os.environ["WEATHER_CSV"]
AWATTAR_CSV = os.environ["AWATTAR_CSV"]
```

Read the meter file with a header and inferred types (small data — inference is fine here):

```python
meter_raw = spark.read.option("header", True).option("inferSchema", True).csv(METER_CSV)
meter_raw.printSchema()
meter_raw.show(5, truncate=False)
meter_raw.count()
```

The first column is the reading time; the CSV header calls it `timestamp`. For production pipelines you prefer an explicit schema so a bad row cannot widen a column type. Spark maps CSV fields **by position** when you supply a schema — name the first field `ts_utc` even though the header says `timestamp`:

```python
meter = (
    spark.read.option("header", True)
    .schema(
        "ts_utc STRING, station_id STRING, device_id STRING, phase STRING, "
        "active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE, "
        "current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE, "
        "transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, "
        "comm_status STRING"
    )
    .csv(METER_CSV)
    .withColumn("ts_utc", F.to_timestamp("ts_utc"))
)
meter.count()
```

Load weather the same way (two operator stations, 15-minute steps):

```python
weather = (
    spark.read.option("header", True)
    .schema(
        "ts_utc STRING, weather_station_id STRING, station_name STRING, "
        "temperature_c DOUBLE, relative_humidity_pct INT, wind_speed_mps DOUBLE, "
        "precipitation_mm DOUBLE, pressure_hpa DOUBLE, weather_quality STRING"
    )
    .csv(WEATHER_CSV)
    .withColumn("ts_utc", F.to_timestamp("ts_utc"))
)
weather.count()
```

You should see **15** meter rows and **10** weather rows (header excluded).

**Check question:** Why is explicit schema safer than `inferSchema=true` on a large landing folder?

---

## 2. Cleanse — filters and lazy evaluation

**Goal:** Keep quality-approved readings, normalize null event codes, and see how actions trigger work.

Transformations are **lazy** until an **action** (`count`, `show`, `write`) runs:

```python
meter_ok = (
    meter.filter(F.col("quality_flag") == "OK")
    .withColumn(
        "event_code",
        F.when(F.trim(F.col("event_code")) == "", None).otherwise(F.col("event_code")),
    )
    .dropDuplicates(["ts_utc", "station_id", "device_id", "phase"])
)
rejected = meter.count() - meter_ok.count()
print(f"rejected_rows={rejected}")
meter_ok.count()
```

You should see **3** rejected rows (WARN quality flags in the sample) and **12** cleansed rows. Watch the Spark UI — the first `count()` on `meter_ok` schedules a new job.

**Check question:** If you chain ten `filter` calls but never call `count`, does YARN start executors?

---

## 3. Aggregate — DataFrame API and Spark SQL

**Goal:** Summarize average power and peak load per transformer station and hour.

```python
hourly = (
    meter_ok.withColumn("hour_utc", F.date_trunc("hour", F.col("ts_utc")))
    .groupBy("station_id", "hour_utc")
    .agg(
        F.avg("active_power_kw").alias("avg_power_kw"),
        F.max("transformer_load_pct").alias("max_load_pct"),
        F.count("*").alias("reading_count"),
    )
    .orderBy("station_id", "hour_utc")
)
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

## 4. Join — align timestamps

**Goal:** Attach operator weather to each meter reading at the same 15-minute timestamp, and add hourly market prices.

The sample weather stations (`GRID-WS-01`, `GRID-WS-02`) differ from transformer IDs (`TS-101`, …) — you join on **time** only, so each meter row matches **both** weather stations at that timestamp:

```python
joined = meter_ok.join(weather, on="ts_utc", how="inner")
joined.count()
```

You should get **24** rows (12 meter × 2 weather stations per timestamp). Try a **left** join and compare:

```python
meter_ok.join(weather, on="ts_utc", how="left").count()
```

Add hourly **awattar** prices by truncating meter time to the hour:

```python
prices = (
    spark.read.option("header", True)
    .schema(
        "price_start STRING, price_end STRING, market STRING, "
        "price_eur_mwh DOUBLE, price_ct_kwh DOUBLE, currency STRING"
    )
    .csv(AWATTAR_CSV)
    .withColumn("price_hour", F.date_trunc("hour", F.to_timestamp("price_start")))
)

curated = (
    joined.withColumn("price_hour", F.date_trunc("hour", F.col("ts_utc")))
    .join(
        prices.select("price_hour", "price_eur_mwh", "market"),
        on="price_hour",
        how="left",
    )
    .drop("price_hour")
)
curated.show(5, truncate=False)
```

**Check question:** With an inner join on time only, why does one meter timestamp produce two output rows?

---

## 5. Write Parquet — curated layer on HDFS

**Goal:** Persist the joined dataset as partitioned Parquet under your HDFS home.

```python
out_interactive = f"/user/{WORKSHOP_USER}/spark-curated"
(
    curated.write.mode("overwrite")
    .partitionBy("station_id")
    .parquet(out_interactive)
)
```

Exit PySpark (`exit()` or Ctrl-D) and inspect the layout from bash:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/spark-curated"
hdfs dfs -ls "/user/${WORKSHOP_USER}/spark-curated/station_id=TS-101"
hdfs dfs -du -s -h "/user/${WORKSHOP_USER}/spark-curated"
```

You should see `_SUCCESS`, one directory per `station_id`, and Parquet part files inside. This is your **curated** layer: columnar files ready for Hive, Impala, or the next Spark job — landing CSVs stay untouched under `${WORKSHOP_ROOT}/data`.

---

## 6. Batch — spark-submit on YARN

**Goal:** Run the same pipeline as a batch job with the shared script on HDFS.

Admin setup placed `spark_cleanse_join.py` under `${SPARK_LAB}/assets/`. Submit in **cluster** mode so the driver runs in YARN (logs via `yarn logs`, as in the YARN basics lab):

```bash
spark-submit --master yarn --deploy-mode cluster \
  --name "spark-batch-${WORKSHOP_USER}" \
  "hdfs://${SPARK_LAB}/assets/spark_cleanse_join.py" \
  "${METER_CSV}" "${WEATHER_CSV}" "${AWATTAR_CSV}" \
  "/user/${WORKSHOP_USER}/spark-batch-curated"
```

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

---

## 7. Relate — register Parquet in the Metastore

**Goal:** Point an external Hive table at your curated Parquet so SQL engines can query it.

Start PySpark again (or use `spark-sql` with the same `--master yarn` if your handout recommends it). Re-import `os` and `WORKSHOP_USER` if this is a fresh shell:

```bash
pyspark --master yarn --name "spark-metastore-${WORKSHOP_USER}"
```

```python
import os
WORKSHOP_USER = os.environ["WORKSHOP_USER"]
batch_path = f"/user/{WORKSHOP_USER}/spark-batch-curated"
```

Create your personal database and external table over the batch output path:

```python
spark.sql(f"CREATE DATABASE IF NOT EXISTS ws_{WORKSHOP_USER}")
spark.sql(f"USE ws_{WORKSHOP_USER}")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS spark_curated_join
USING parquet
LOCATION '{batch_path}'
""")
spark.sql("SELECT COUNT(*) AS rows, COUNT(DISTINCT station_id) AS stations FROM spark_curated_join").show()
```

You should see **24** rows and **3** stations. **Optional cross-check** in Beeline (second terminal):

```bash
beeline -u "${HS2_URL}" -e "
USE ws_${WORKSHOP_USER};
SELECT station_id, COUNT(*) AS n FROM spark_curated_join GROUP BY station_id ORDER BY station_id;
"
```

Hive and Impala read the same Metastore entry — no copy step. Use **external** tables here so dropping the table does not delete Parquet files (managed table semantics are covered in the Hive basics module).

---

## 8. Optional — failure signals on YARN

**Goal:** Provoke three common failures and read the signal in the shell or YARN logs.

**Wrong input path** — expect `AnalysisException` or `Path does not exist`:

```python
spark.read.csv("/no/such/workshop/path").count()
```

**Output path already exists** — in PySpark, reload the batch output and write again without `overwrite`:

```python
import os
u = os.environ["WORKSHOP_USER"]
again = spark.read.parquet(f"/user/{u}/spark-batch-curated")
again.write.parquet(f"/user/{u}/spark-batch-curated")
```

**Executor memory too small** — submit the batch script with an unrealistically tiny executor heap (may stay `ACCEPTED` or fail with `Container killed`):

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

- Repartition `curated` to 1 file per station with `repartition(1, "station_id")` before write; compare part-file counts with section 5.  
- Run `curated.explain(True)` before the join and discuss shuffle stages.  
- `cache()` `meter_ok`, run two aggregations, and compare timings in the Spark UI storage tab.

---

## Self-check

From the repo on the edge node:

```bash
./06-basics-spark/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
