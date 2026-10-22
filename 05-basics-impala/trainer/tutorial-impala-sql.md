# Impala SQL quick tour

Minimal run-through of data types and core statements. Run in `impala-shell` or Hue (Impala editor). Impala SQL is close to Hive SQL; the differences are called out below. Everything uses a scratch database and inline data.

```sql
CREATE DATABASE IF NOT EXISTS tour_impala;
USE tour_impala;
```

---

## 1. Data types

| Group | Types |
|---|---|
| Numeric | `TINYINT`, `SMALLINT`, `INT`, `BIGINT`, `FLOAT`, `DOUBLE`, `DECIMAL(p,s)` |
| Text | `STRING`, `VARCHAR(n)`, `CHAR(n)` |
| Boolean | `BOOLEAN` |
| Date/time | `TIMESTAMP`, `DATE` (Impala 4.1+ / recent CDP) |
| Complex | `ARRAY<T>`, `MAP<K,V>`, `STRUCT<...>` (Parquet/ORC tables only, read via `table.col` syntax) |

```sql
CREATE TABLE types_demo (
  id      INT,
  name    STRING,
  price   DECIMAL(8,2),
  active  BOOLEAN,
  seen_at TIMESTAMP
)
STORED AS PARQUET;

INSERT INTO types_demo VALUES
  (1, 'meter-A', 19.90, true, '2026-01-15 10:30:00');

SELECT * FROM types_demo;
```

Complex types: Impala cannot insert them with `VALUES`; query them as nested collections in the `FROM` clause.

```sql
CREATE TABLE nested_demo (id INT, tags ARRAY<STRING>) STORED AS PARQUET;
-- (fill via Hive or Spark) then:
SELECT n.id, t.item FROM nested_demo n, n.tags t;
```

---

## 2. Tables

```sql
SHOW TABLES;
DESCRIBE types_demo;

CREATE TABLE readings (meter_id STRING, ts TIMESTAMP, kwh DOUBLE)
STORED AS PARQUET;

CREATE EXTERNAL TABLE readings_ext LIKE readings;
```

---

## 3. INSERT, UPDATE, DELETE

```sql
INSERT INTO readings VALUES
  ('M1', '2026-01-01 00:00:00', 1.5),
  ('M1', '2026-01-01 01:00:00', 2.0),
  ('M2', '2026-01-01 00:00:00', 0.7);

INSERT OVERWRITE readings SELECT * FROM readings WHERE kwh > 0;   -- replace contents
```

`UPDATE` and `DELETE` work only on **Kudu** and **Iceberg** tables, not on plain Parquet/ORC:

```sql
CREATE TABLE readings_kudu (meter_id STRING, kwh DOUBLE, PRIMARY KEY (meter_id))
PARTITION BY HASH (meter_id) PARTITIONS 2
STORED AS KUDU;

UPSERT INTO readings_kudu VALUES ('M1', 1.5), ('M2', 0.7);
UPDATE readings_kudu SET kwh = 0 WHERE meter_id = 'M2';
DELETE FROM readings_kudu WHERE kwh = 0;
```

(Kudu may not be installed in your cluster; Iceberg is covered in [module 07](../../07-lakehouse-iceberg/).)

---

## 4. SELECT basics

```sql
SELECT * FROM readings LIMIT 5;

SELECT meter_id, kwh
FROM readings
WHERE kwh > 1 AND meter_id IN ('M1','M3')
ORDER BY kwh DESC;
```

---

## 5. Aggregation

```sql
SELECT meter_id,
       COUNT(*) AS n,
       SUM(kwh) AS total,
       AVG(kwh) AS avg_kwh,
       MAX(kwh) AS peak
FROM readings
GROUP BY meter_id
HAVING SUM(kwh) > 1;
```

---

## 6. Joins

```sql
CREATE TABLE meters (meter_id STRING, city STRING) STORED AS PARQUET;
INSERT INTO meters VALUES ('M1','Vienna'), ('M3','Graz');

SELECT r.meter_id, m.city, r.kwh
FROM readings r JOIN meters m ON r.meter_id = m.meter_id;

SELECT m.meter_id, r.kwh
FROM meters m LEFT JOIN readings r ON r.meter_id = m.meter_id;
```

---

## 7. Common functions

```sql
SELECT
  upper('abc'), concat('a','-','b'), substr('workshop',1,4),   -- strings
  round(3.14159, 2), floor(2.7), abs(-5),                      -- numbers
  now(), year(ts), date_add(ts, 7),                            -- dates
  CAST('42' AS INT),                                           -- casting
  COALESCE(kwh, 0),                                            -- NULL handling
  CASE WHEN kwh > 1.8 THEN 'high' ELSE 'normal' END AS level
FROM readings LIMIT 1;
```

---

## 8. CTE and window function

```sql
WITH hourly AS (SELECT meter_id, ts, kwh FROM readings)
SELECT meter_id, ts, kwh,
       SUM(kwh) OVER (PARTITION BY meter_id ORDER BY ts) AS running_total,
       ROW_NUMBER() OVER (PARTITION BY meter_id ORDER BY kwh DESC) AS rn
FROM hourly;
```

---

## 9. Partitions

```sql
CREATE TABLE readings_part (meter_id STRING, kwh DOUBLE)
PARTITIONED BY (day STRING)
STORED AS PARQUET;

INSERT INTO readings_part PARTITION (day='2026-01-01') VALUES ('M1', 1.5), ('M2', 0.7);

SHOW PARTITIONS readings_part;
SELECT * FROM readings_part WHERE day = '2026-01-01';   -- partition pruning
```

---

## 10. Impala specifics: metadata, statistics, explain

Impala caches table metadata. Changes made outside Impala (Hive, Spark, files added to HDFS) are not visible until you refresh.

```sql
INVALIDATE METADATA readings;   -- table created/changed outside Impala (heavy)
REFRESH readings;               -- new data files added to an existing table (light)

COMPUTE STATS readings;         -- gives the planner row counts; do this after loading data
SHOW TABLE STATS readings;
SHOW COLUMN STATS readings;

EXPLAIN SELECT meter_id, SUM(kwh) FROM readings GROUP BY meter_id;
```

In `impala-shell`, run `PROFILE;` right after a query for the runtime profile.

---

## 11. Clean up

```sql
DROP DATABASE tour_impala CASCADE;
```

---

## Hive vs. Impala at a glance

| | Hive | Impala |
|---|---|---|
| Engine | Tez, batch | MPP daemons, interactive |
| Metadata | Always current | Cached: `REFRESH` / `INVALIDATE METADATA` |
| `UPDATE`/`DELETE` | Managed ACID tables | Kudu, Iceberg |
| Statistics | `ANALYZE TABLE` | `COMPUTE STATS` |
| Complex type access | `LATERAL VIEW explode` | Nested `FROM` join syntax |

## Timing hint

About 15 minutes. Skip sections 8–9 if short on time.
