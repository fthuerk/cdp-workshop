# Spark SQL / PySpark guided tour

Run-through of Spark basics: first a short look at the Scala shell (`spark3-shell`), then a step-by-step PySpark tour of data types and core operations, using the SQL and DataFrame APIs side by side. Everything uses inline data.

Suggested flow: Spark and Scala context (section 0) -> DataFrame basics (1-4) -> transformations (5-10) -> structure and performance (11-16) -> wrap-up exercise (17) -> batch job (18).

---

## 0. Warm-up: `spark3-shell` (Scala) — instructor talk track

Spark itself is written in Scala and runs on the JVM. PySpark is a Python API on top of the same engine: DataFrame and SQL code is planned by the same optimizer (Catalyst), so performance is the same. Only Python UDFs and `collect()` / `toPandas()` cross the Python/JVM boundary.

```bash
kinit                # on a Kerberized edge node
spark3-shell         # Scala REPL; `spark` (SparkSession) and `sc` (SparkContext) are predefined
```

```scala
// values are immutable (val), variables mutable (var); types are inferred
val nums = Seq(1, 2, 3, 4, 5)
val squares = nums.map(x => x * x)          // functional style: map / filter / reduce
squares.sum

// the same idea, distributed: a DataFrame from a local collection
import spark.implicits._
val readings = Seq(("M1", 1.5), ("M1", 2.0), ("M2", 0.7)).toDF("meter_id", "kwh")

readings.printSchema()
readings.filter($"kwh" > 1).show()
readings.groupBy("meter_id").sum("kwh").show()

// SQL works identically
readings.createOrReplaceTempView("r")
spark.sql("SELECT meter_id, avg(kwh) FROM r GROUP BY meter_id").show()
```

Talking points:

- `scala>` prompt vs `>>>` prompt: same `spark` object, same results. Spark Scala/Java APIs get new features first; Python is the most common choice for data teams.
- Typed `Dataset[T]` exists only in Scala/Java; in Python we always work with `DataFrame`.
- Point out the startup banner: Spark version, Web UI URL, `master = yarn`.
- Leave with `:quit` (or Ctrl-D), then start PySpark.

---

## Setup for the PySpark tour

```bash
pyspark    # on a Kerberized edge node: kinit first
```

```python
from pyspark.sql import functions as F
from pyspark.sql import types as T

spark.sql("CREATE DATABASE IF NOT EXISTS <username>")
spark.sql("USE <username>")

spark.version                  # which Spark are we on?
```

`spark` is the `SparkSession`, the single entry point for DataFrames, SQL and the catalog.

---

## 1. Data types

| Group | Types |
|---|---|
| Numeric | `ByteType`, `ShortType`, `IntegerType`, `LongType`, `FloatType`, `DoubleType`, `DecimalType(p,s)` |
| Text | `StringType` |
| Boolean | `BooleanType` |
| Date/time | `DateType`, `TimestampType` |
| Complex | `ArrayType`, `MapType`, `StructType` |

SQL names: `INT`, `BIGINT`, `DOUBLE`, `DECIMAL(8,2)`, `STRING`, `BOOLEAN`, `DATE`, `TIMESTAMP`, `ARRAY<>`, `MAP<,>`, `STRUCT<>`.

```python
df = spark.sql("""
  SELECT 1 AS id, 'meter-A' AS name, CAST(19.90 AS DECIMAL(8,2)) AS price, true AS active,
         DATE '2026-01-15' AS created, TIMESTAMP '2026-01-15 10:30:00' AS seen_at,
         array('indoor','smart') AS tags, map('vendor','x') AS attrs,
         named_struct('city','Vienna','zip',1010) AS location
""")

df.printSchema()
df.select("id", df.tags[0], df.attrs["vendor"], "location.city").show()
```

---

## 2. Create DataFrames and tables

A DataFrame is a distributed table with a schema. It is immutable: every operation returns a new DataFrame.

```python
readings = spark.createDataFrame(
    [("M1", "2026-01-01 00:00:00", 1.5),
     ("M1", "2026-01-01 01:00:00", 2.0),
     ("M2", "2026-01-01 00:00:00", 0.7),
     ("M2", "2026-01-02 00:00:00", None)],
    "meter_id string, ts string, kwh double"
).withColumn("ts", F.to_timestamp("ts"))

readings.createOrReplaceTempView("readings_v")     # session-only SQL view
readings.write.mode("overwrite").saveAsTable("readings")   # persistent table

spark.sql("SHOW TABLES").show()
spark.sql("DESCRIBE readings").show()
```

Quick inspection toolbox:

```python
readings.show(truncate=False)   # first rows
readings.columns                # list of column names
readings.dtypes                 # (name, type) pairs
readings.count()                # number of rows (action)
readings.describe("kwh").show() # count / mean / stddev / min / max
spark.table("readings").show()  # read a table back as DataFrame
```

---

## 3. Explicit schemas

`inferSchema` is convenient but costs an extra pass over the data and can guess wrong. For production code, define the schema.

```python
schema = T.StructType([
    T.StructField("meter_id", T.StringType(), False),    # False = not nullable
    T.StructField("ts",       T.TimestampType(), True),
    T.StructField("kwh",      T.DoubleType(), True),
])

import datetime as dt
rows = [("M3", dt.datetime(2026, 1, 3, 8, 0), 3.2),
        ("M3", dt.datetime(2026, 1, 3, 9, 0), 2.8)]
more = spark.createDataFrame(rows, schema)
more.printSchema()
```

### Demo: when `inferSchema` guesses wrong

Meter IDs with leading zeros and one dirty value (`n/a`) in a numeric column. The CSV lines are inline, no file needed:

```python
lines = spark.sparkContext.parallelize([
    "meter_id,ts,kwh",
    "007,2026-01-01 00:00:00,1.5",
    "008,2026-01-01 01:00:00,12.0",
    "009,2026-01-01 02:00:00,9.5",
    "010,2026-01-01 03:00:00,n/a",
])

guessed = spark.read.option("header", True).option("inferSchema", True).csv(lines)
guessed.printSchema()
guessed.show()
```

What went wrong:

- `meter_id` was inferred as `int`: `007` became `7`, the leading zeros are lost for good.
- `kwh` was inferred as `string` because of one `n/a`: the whole column is text now.

See the consequences. Both look harmless, but the results are wrong:

```python
guessed.orderBy(F.desc("kwh")).show()      # expected: 12.0, 9.5, 1.5 ... but it sorts as TEXT: n/a, 9.5, 12.0, 1.5
guessed.agg(F.max("kwh")).show()           # expected 12.0, but the maximum of the text values is "n/a"
```

Text order compares character by character: `"9.5"` is "greater" than `"12.0"` because `"9"` > `"1"`. Spark does not warn; a report built on this would show the wrong peak.

Now with an explicit schema, same data:

```python
fixed_schema = "meter_id string, ts timestamp, kwh double"
fixed = spark.read.option("header", True).schema(fixed_schema).csv(lines)

fixed.printSchema()
fixed.show()                                               # 007 stays "007"; n/a becomes NULL
fixed.orderBy(F.desc("kwh")).show()                        # numeric order: 12.0, 9.5, 1.5, NULL
fixed.agg(F.max("kwh")).show()                             # 12.0
```

Take-away: `inferSchema` looks at the data it sees (and reads all of it once), so one dirty value or an ID that looks numeric changes the type. An explicit schema makes the contract visible and stable, and bad values become NULL instead of changing the column type.

---

## 4. Read and write files

```python
readings.write.mode("overwrite").parquet("/user/<username>/hol_spark/readings_parquet")
readings.write.mode("overwrite").option("header", True).csv("/user/<username>/hol_spark/readings_csv")
readings.write.mode("overwrite").json("/user/<username>/hol_spark/readings_json")

spark.read.parquet("/user/<username>/hol_spark/readings_parquet").show()
spark.read.option("header", True).option("inferSchema", True) \
     .csv("/user/<username>/hol_spark/readings_csv").printSchema()

# CSV with an explicit schema (no extra pass over the data)
spark.read.schema(schema).option("header", True).csv("/user/<username>/hol_spark/readings_csv").show()

# JSON: one object per line, schema is inferred
spark.read.json("/user/<username>/hol_spark/readings_json").show()
```

Write modes (`.mode(...)`):

| Mode | If the target already exists |
|---|---|
| `error` / `errorifexists` (default) | fails with an `AnalysisException` |
| `overwrite` | deletes the existing data, writes the new data |
| `append` | adds the new files next to the existing ones |
| `ignore` | does nothing, silently skips the write |

Run the same write twice to see it: with the default, the second run fails; with `append`, the row count doubles.

Formats: Parquet is columnar, compressed, and keeps the schema — the default choice for analytics. CSV/JSON are for exchange.

```bash
hdfs dfs -ls /user/<username>/hol_spark/readings_parquet    # note: a directory of part-files, one per task
```

### One task = one file: `coalesce(1)`

Spark writes one file per partition (per task), in parallel. Make that visible by writing the same JSON data twice, with 4 partitions and then with 1:

```python
# 4 partitions -> 4 tasks -> 4 part-files (small data, but the principle is the same)
readings.repartition(4).write.mode("overwrite").json("/user/<username>/hol_spark/readings_json")

# 1 partition -> 1 task -> 1 part-file
readings.coalesce(1).write.mode("overwrite").json("/user/<username>/hol_spark/readings_json")
```

```bash
hdfs dfs -ls /user/<username>/hol_spark/readings_json    # run after each write: 4 part-files, then 1
hdfs dfs -cat /user/<username>/hol_spark/readings_json/part-*    # all rows are in the single file
```

Why it matters: many small files burden the NameNode and slow later reads, so `coalesce(1)` (or a small number) is useful for small outputs, e.g. a report someone downloads. For large data, one file means one task writing everything: no parallelism and a potential memory/time bottleneck. Output is always a *directory* of part-files, even with one partition.

`coalesce` vs `repartition`:

| | `coalesce(n)` | `repartition(n)` |
|---|---|---|
| Direction | only reduces the number of partitions | increases or decreases |
| Shuffle | no full shuffle: merges existing partitions on the same executor | full shuffle: data is redistributed across the network |
| Cost | cheap | more expensive |
| Balance | partitions may end up uneven | roughly even partitions |
| Typical use | reduce files before a write | increase parallelism, rebalance skewed data, partition by column: `repartition(8, "meter_id")` |

Caveat: `coalesce(1)` before a heavy computation can pull the whole preceding stage into one task. If that matters, use `repartition(1)` so the work before it stays parallel and only the final step has one partition.

---

## 5. SELECT, filter, sort

```python
spark.sql("""
  SELECT meter_id, kwh FROM readings
  WHERE kwh > 1 AND meter_id IN ('M1','M3')
  ORDER BY kwh DESC
""").show()

# same as DataFrame API
readings.filter((F.col("kwh") > 1) & F.col("meter_id").isin("M1", "M3")) \
        .select("meter_id", "kwh").orderBy(F.desc("kwh")).show()
```

Note: in the DataFrame API use `&`, `|`, `~` with parentheses (not `and`, `or`, `not`).

---

## 6. Add, rename, drop columns

```python
enriched = (readings
    .withColumn("day", F.to_date("ts"))                    # add column
    .withColumn("hour", F.hour("ts"))
    .withColumn("wh", F.col("kwh") * 1000)                 # derived value
    .withColumnRenamed("kwh", "energy_kwh")                # rename
    .drop("wh"))                                           # remove

enriched.show()

# selectExpr: SQL snippets inside the DataFrame API
readings.selectExpr("meter_id", "kwh * 1000 AS wh", "year(ts) AS yr").show()

# distinct values and de-duplication
readings.select("meter_id").distinct().show()
readings.dropDuplicates(["meter_id"]).show()
```

---

## 7. Aggregation

```python
readings.groupBy("meter_id").agg(
    F.count("*").alias("n"),
    F.count("kwh").alias("n_non_null"),     # count(col) skips NULLs, count(*) does not
    F.sum("kwh").alias("total"),
    F.avg("kwh").alias("avg_kwh"),
    F.max("kwh").alias("peak"),
).show()

# group by a derived column
readings.groupBy(F.to_date("ts").alias("day")).agg(F.sum("kwh").alias("daily_kwh")).orderBy("day").show()
```

SQL equivalent: `SELECT meter_id, COUNT(*), SUM(kwh) ... GROUP BY meter_id`.

Pivot: turn values into columns.

```python
readings.withColumn("day", F.to_date("ts")) \
        .groupBy("meter_id").pivot("day").sum("kwh").show()
```

---

## 8. Joins and set operations

```python
meters = spark.createDataFrame([("M1", "Vienna"), ("M3", "Graz")], "meter_id string, city string")

readings.join(meters, "meter_id", "inner").show()
meters.join(readings, "meter_id", "left").show()    # M3 appears with NULL

# other join types
readings.join(meters, "meter_id", "left_anti").show()   # readings without a known meter
readings.join(meters, "meter_id", "left_semi").show()   # readings with a known meter (no extra columns)

# broadcast hint: ship the small table to every executor, avoids a shuffle
readings.join(F.broadcast(meters), "meter_id").explain()   # look for BroadcastHashJoin

# union: stack DataFrames with the same columns
readings.unionByName(more).show()
```

---

## 9. Common functions and NULL handling

```python
readings.select(
    F.upper(F.lit("abc")), F.concat_ws("-", F.lit("a"), F.lit("b")), F.substring(F.lit("workshop"), 1, 4),
    F.round(F.lit(3.14159), 2), F.floor(F.lit(2.7)),
    F.current_date(), F.year("ts"), F.date_add(F.to_date("ts"), 7),
    F.col("kwh").cast("int"),
    F.coalesce("kwh", F.lit(0)),
    F.when(F.col("kwh") > 1.8, "high").otherwise("normal").alias("level"),
).show(2)

readings.na.fill({"kwh": 0}).show()     # replace NULLs
readings.dropna().show()                # drop rows with NULLs
readings.filter(F.col("kwh").isNull()).show()   # find NULLs (never use == None)
```

String and regex helpers:

```python
raw = spark.createDataFrame([(" Meter-M1 ",), ("meter-m2",)], "label string")
raw.select(
    F.trim("label").alias("trimmed"),
    F.lower(F.trim("label")).alias("lower"),
    F.regexp_extract("label", r"[Mm](\d+)", 1).alias("number"),
    F.split(F.trim("label"), "-").alias("parts"),
).show(truncate=False)
```

Prefer built-in functions over Python UDFs: built-ins run inside the JVM and the optimizer understands them.

```python
@F.udf("string")                       # works, but slower: rows travel JVM <-> Python
def bucket(kwh):
    return None if kwh is None else ("high" if kwh > 1.8 else "normal")

readings.select("kwh", bucket("kwh").alias("level_udf")).show()
```

---

## 10. Window function and CTE

```python
spark.sql("""
  WITH r AS (SELECT * FROM readings WHERE kwh IS NOT NULL)
  SELECT meter_id, ts, kwh,
         SUM(kwh) OVER (PARTITION BY meter_id ORDER BY ts) AS running_total,
         ROW_NUMBER() OVER (PARTITION BY meter_id ORDER BY kwh DESC) AS rn
  FROM r
""").show()
```

Same with the DataFrame API, plus `lag` to compare with the previous reading:

```python
from pyspark.sql.window import Window

w = Window.partitionBy("meter_id").orderBy("ts")

readings.dropna().select(
    "meter_id", "ts", "kwh",
    F.lag("kwh").over(w).alias("prev_kwh"),
    (F.col("kwh") - F.lag("kwh").over(w)).alias("delta"),
    F.sum("kwh").over(w).alias("running_total"),
).show()
```

Typical use: "latest reading per meter" = `row_number()` over `ts DESC`, then filter `rn = 1`.

---

## 11. Complex types: explode

```python
df.select("id", F.explode("tags").alias("tag")).show()

# build complex values
readings.groupBy("meter_id").agg(F.collect_list("kwh").alias("all_kwh")).show(truncate=False)
readings.select("meter_id", F.struct("ts", "kwh").alias("reading")).printSchema()
```

---

## 12. Partitioned write

```python
readings.withColumn("day", F.to_date("ts")) \
        .write.mode("overwrite").partitionBy("day").saveAsTable("readings_part")

spark.sql("SHOW PARTITIONS readings_part").show()
spark.sql("SELECT * FROM readings_part WHERE day = '2026-01-01'").show()   # pruning
```

Check the layout: `hdfs dfs -ls` on the table location shows one `day=...` directory per value. Partition on low-cardinality columns (date, region), not on IDs.

---

## 13. Lazy evaluation, explain, caching

Transformations (`filter`, `select`, `groupBy`, `join`) are lazy. Actions (`show`, `count`, `write`, `collect`) run the job.

```python
q = readings.groupBy("meter_id").sum("kwh")
q.explain()        # physical plan; no job has run yet
q.show()           # action: job appears in the Spark History Server

readings.cache()   # keep in memory for repeated use
readings.count()
readings.unpersist()
```

Show the plan in more detail:

```python
q.explain("formatted")     # readable plan: Scan -> HashAggregate -> Exchange -> HashAggregate
```

`Exchange` = shuffle = data moves across the network. Fewer shuffles, faster jobs.

---

## 14. RDD vs DataFrame vs Python UDF: the speed trade-off

Same computation, three ways: double every `kwh` value and sum it. Only the execution path differs.

```python
import time

def timed(label, fn):
    t = time.time(); r = fn()
    print(f"{label:<26} {time.time() - t:6.1f}s  -> {r}")

N = 20_000_000
big_df = spark.range(N).withColumn("kwh", (F.col("id") % 100) / 10.0)
big_df.cache().count()                          # materialize once so all variants read the same data

# 1. RDD with a Python lambda: every row is pickled JVM <-> Python, no optimizer
timed("RDD (Python lambda)", lambda: big_df.rdd.map(lambda r: r.kwh * 2).sum())

# 2. DataFrame + Python UDF: still one Python call per row
double_udf = F.udf(lambda x: x * 2.0, "double")
timed("DataFrame + Python UDF", lambda: big_df.select(F.sum(double_udf("kwh"))).first()[0])

# 3. DataFrame + built-in functions: stays in the JVM, optimized and code-generated
timed("DataFrame built-in", lambda: big_df.select(F.sum(F.col("kwh") * 2)).first()[0])

big_df.unpersist()
```

Expected: built-in is several times faster than the UDF, and the UDF is usually a bit faster than the RDD. Exact ratios depend on the cluster, so run it once beforehand.

Look at the plans:

```python
big_df.select(F.sum(double_udf("kwh"))).explain()   # contains BatchEvalPython: rows leave the JVM
big_df.select(F.sum(F.col("kwh") * 2)).explain()    # no Python step, whole-stage codegen
```

Open the Spark History Server: compare task durations for the three jobs.

Talking points:

- **RDD:** low-level, no schema, no optimizer. Use for unstructured data or custom partitioning logic.
- **DataFrame:** schema plus Catalyst (optimizer) and Tungsten (memory/codegen). With built-in functions, PySpark is as fast as Scala.
- The PySpark slowdown comes from serializing rows to Python workers, not from the API itself.
- Middle ground when you need Python logic: Pandas UDFs (`@F.pandas_udf`), which move data in Arrow batches instead of row by row.
- Scala link (section 0): typed `Dataset` lambdas have a similar, smaller cost; the same rule applies: built-ins first.

---

## 15. Partitions, shuffles and `repartition`

```python
big = spark.range(0, 10_000_000)               # synthetic data, column "id"
big.rdd.getNumPartitions()                     # how the data is split across tasks

spark.conf.get("spark.sql.shuffle.partitions") # partitions after a shuffle (default 200)

big.groupBy((F.col("id") % 10).alias("k")).count().show()   # check stages and tasks in the History Server

big.repartition(8).rdd.getNumPartitions()      # full shuffle, increases or balances
big.coalesce(2).rdd.getNumPartitions()         # no shuffle, only reduces
```

Rule of thumb: one task per partition, ideally 100-200 MB per partition. Too many tiny tasks and too few huge ones are both slow. Adaptive Query Execution (`spark.sql.adaptive.enabled`) tunes much of this automatically in Spark 3.

---

## 16. Moving data between Spark and Python

```python
small = readings.groupBy("meter_id").sum("kwh")

small.collect()                 # list of Row objects to the driver: only for small results
small.toPandas()                # pandas DataFrame on the driver: only for small results
spark.createDataFrame(small.toPandas())    # and back
```

Never `collect()` or `toPandas()` a large table: the driver runs out of memory. Aggregate or `limit()` first.

---

## 17. Mini exercise (participants, ~5 min)

Task: *for each meter, show the city, the total kWh and the share of the total consumption in percent. Meters without readings should still appear.*

Solution:

```python
total = readings.agg(F.sum("kwh")).first()[0]

(meters.join(readings.groupBy("meter_id").agg(F.sum("kwh").alias("kwh")), "meter_id", "left")
       .withColumn("share_pct", F.round(F.coalesce("kwh", F.lit(0)) / total * 100, 1))
       .show())
```

Same in SQL:

```python
spark.sql("""
  SELECT m.meter_id, m.city, SUM(r.kwh) AS kwh,
         ROUND(COALESCE(SUM(r.kwh), 0) / SUM(SUM(r.kwh)) OVER () * 100, 1) AS share_pct
  FROM (SELECT 'M1' AS meter_id, 'Vienna' AS city UNION ALL SELECT 'M3', 'Graz') m
  LEFT JOIN readings r ON r.meter_id = m.meter_id
  GROUP BY m.meter_id, m.city
""").show()
```

---

## 18. Run it as a batch job: `spark3-submit` with a PySpark script

Interactive shells are for exploring. Scheduled and production jobs are Python files run with `spark3-submit` (there is no separate "pyspark-submit"; PySpark scripts use the normal submit command).

Create the script `meter_report.py` on the edge node:

```python
import getpass
import sys
import time
from pyspark.sql import SparkSession, functions as F

def main(out_path, rounds=6):
    # no predefined `spark` in a script; enableHiveSupport() connects to the Hive Metastore
    # (hive-site.xml is preconfigured on the cluster)
    spark = (SparkSession.builder
             .appName("meter_report")
             .enableHiveSupport()
             .getOrCreate())

    # Demo load: several rounds of shuffle-heavy work with a pause in between.
    # Keeps the application RUNNING for ~3-4 minutes, so the trainer can open the
    # Spark History Server (incomplete applications) while jobs are being added.
    for i in range(rounds):
        n = (spark.range(0, 30_000_000, numPartitions=16)
                  .groupBy((F.col("id") % 1000).alias("k")).count()
                  .count())
        print(f"round {i + 1}/{rounds}: {n} groups")
        time.sleep(25)

    readings = spark.createDataFrame(
        [("M1", "2026-01-01 00:00:00", 1.5),
         ("M1", "2026-01-01 01:00:00", 2.0),
         ("M2", "2026-01-01 00:00:00", 0.7),
         ("M2", "2026-01-02 00:00:00", None)],
        "meter_id string, ts string, kwh double"
    ).withColumn("ts", F.to_timestamp("ts"))

    report = (readings.dropna()
              .groupBy("meter_id")
              .agg(F.sum("kwh").alias("total_kwh"), F.max("kwh").alias("peak_kwh")))

    report.show()
    report.write.mode("overwrite").parquet(out_path)
    spark.stop()

if __name__ == "__main__":
    default_out = f"/user/{getpass.getuser()}/hol_spark/meter_report"   # per-user path, no clashes
    main(sys.argv[1] if len(sys.argv) > 1 else default_out)
```

The script runs about 3-4 minutes on purpose (6 rounds x 1 job + 25 s pause). While it runs:

1. In a second terminal: `yarn application -list -appStates RUNNING -appTypes SPARK` to see the running application. YARN shows exactly **one** application for the whole script, however many Spark jobs it runs inside.
2. Open the Spark History Server (link in Cloudera Manager) and click **Show incomplete applications**: the running app is listed, and the **Jobs** tab gets a new Spark job about every 30 s. Refresh to watch it grow.
3. When it finishes, the app moves to the completed list; compare the final job count (6 + 1 write job) with what you saw live.
4. Change the `rounds` default or the `time.sleep` value to make it shorter or longer.

Submit it:

```bash
kinit
spark3-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 1g \
  --executor-cores 1 \
  --name meter_report \
  meter_report.py /user/<username>/hol_spark/meter_report
```

Check the result and the run:

```bash
hdfs dfs -ls /user/<username>/hol_spark/meter_report
yarn application -list -appStates FINISHED | grep meter_report
```

Talking points:

- `--deploy-mode client`: driver runs on the edge node and prints output to the terminal (good for learning). `cluster`: driver runs inside YARN, the terminal returns only the application ID; use it for scheduled jobs, and read output with `yarn logs -applicationId <id>`.
- Everything after the script name is passed to the script as `sys.argv`.
- Resources are set per job on the command line; compare with the shell, where they were fixed at startup (`pyspark --num-executors ...`).
- Extra Python files or libraries: `--py-files utils.zip`. Config: `--conf spark.sql.shuffle.partitions=50`.
- The finished job appears in the Spark History Server (see `demos.md`).
- Try `--deploy-mode cluster` as a second run to show the difference.

---

## 19. Clean up

```python
# do not drop the database: it is the user's own database. Drop only the tables created here.
spark.sql("DROP TABLE IF EXISTS readings")
spark.sql("DROP TABLE IF EXISTS readings_part")
```

```bash
hdfs dfs -rm -r -f /user/<username>/hol_spark
```

---

## Timing hint

About 35-40 minutes in full.

- Short version (~15 min): section 0 (2-3 min talk), then 1, 2, 5, 7, 8, 13.
- Skip if short on time: 3, 6, 10-12, 15, 16.
- Section 14 (RDD vs DataFrame vs UDF) is a short, high-impact demo (~5 min); keep it if the audience writes PySpark.
- Section 18 (`spark3-submit`) is a good closer even in the short version (~5 min).
- Open the Spark History Server after section 13 (and again after 14 and 15) to show the job, stages and tasks behind one `show()`.
