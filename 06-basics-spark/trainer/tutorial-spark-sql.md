# Spark SQL / PySpark quick tour

Minimal run-through of data types and core operations. Run in `pyspark` (or a Jupyter/CML session), using the SQL and DataFrame APIs side by side. Everything uses inline data.

```bash
pyspark    # on a Kerberized edge node: kinit first
```

```python
spark.sql("CREATE DATABASE IF NOT EXISTS tour_spark")
spark.sql("USE tour_spark")
```

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
from pyspark.sql import functions as F

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

---

## 3. Read and write files

```python
readings.write.mode("overwrite").parquet("/tmp/tour_spark/readings_parquet")
readings.write.mode("overwrite").option("header", True).csv("/tmp/tour_spark/readings_csv")

spark.read.parquet("/tmp/tour_spark/readings_parquet").show()
spark.read.option("header", True).option("inferSchema", True) \
     .csv("/tmp/tour_spark/readings_csv").printSchema()
```

Write modes: `overwrite`, `append`, `ignore`, `error` (default).

---

## 4. SELECT, filter, sort

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

---

## 5. Aggregation

```python
readings.groupBy("meter_id").agg(
    F.count("*").alias("n"),
    F.sum("kwh").alias("total"),
    F.avg("kwh").alias("avg_kwh"),
    F.max("kwh").alias("peak"),
).show()
```

SQL equivalent: `SELECT meter_id, COUNT(*), SUM(kwh) ... GROUP BY meter_id`.

---

## 6. Joins

```python
meters = spark.createDataFrame([("M1", "Vienna"), ("M3", "Graz")], "meter_id string, city string")

readings.join(meters, "meter_id", "inner").show()
meters.join(readings, "meter_id", "left").show()    # M3 appears with NULL
```

---

## 7. Common functions and NULL handling

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
```

---

## 8. Window function and CTE

```python
spark.sql("""
  WITH r AS (SELECT * FROM readings WHERE kwh IS NOT NULL)
  SELECT meter_id, ts, kwh,
         SUM(kwh) OVER (PARTITION BY meter_id ORDER BY ts) AS running_total,
         ROW_NUMBER() OVER (PARTITION BY meter_id ORDER BY kwh DESC) AS rn
  FROM r
""").show()
```

---

## 9. Complex types: explode

```python
df.select("id", F.explode("tags").alias("tag")).show()
```

---

## 10. Partitioned write

```python
readings.withColumn("day", F.to_date("ts")) \
        .write.mode("overwrite").partitionBy("day").saveAsTable("readings_part")

spark.sql("SHOW PARTITIONS readings_part").show()
spark.sql("SELECT * FROM readings_part WHERE day = '2026-01-01'").show()   # pruning
```

---

## 11. Lazy evaluation, explain, caching

Transformations (`filter`, `select`, `groupBy`, `join`) are lazy. Actions (`show`, `count`, `write`, `collect`) run the job.

```python
q = readings.groupBy("meter_id").sum("kwh")
q.explain()        # physical plan; no job has run yet
q.show()           # action: job appears in the Spark UI

readings.cache()   # keep in memory for repeated use
readings.count()
readings.unpersist()
```

---

## 12. Clean up

```python
spark.sql("DROP DATABASE tour_spark CASCADE")
```

```bash
hdfs dfs -rm -r -f /tmp/tour_spark
```

---

## Timing hint

About 15 minutes. Skip sections 8–10 if short on time. Open the Spark UI after section 11 to show the job, stages and tasks behind one `show()`.
