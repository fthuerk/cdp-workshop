# Hive SQL quick tour

Minimal run-through of data types and core statements. Run in Beeline or Hue as your demo user. Everything uses a scratch database and tiny inline data, so no files are needed.

```sql
CREATE DATABASE IF NOT EXISTS tour;
USE tour;
```

---

## 1. Data types

| Group | Types |
|---|---|
| Numeric | `TINYINT`, `SMALLINT`, `INT`, `BIGINT`, `FLOAT`, `DOUBLE`, `DECIMAL(p,s)` |
| Text | `STRING`, `VARCHAR(n)`, `CHAR(n)` |
| Boolean | `BOOLEAN` |
| Date/time | `DATE`, `TIMESTAMP` |
| Complex | `ARRAY<T>`, `MAP<K,V>`, `STRUCT<...>` |

```sql
CREATE TABLE types_demo (
  id        INT,
  name      STRING,
  price     DECIMAL(8,2),
  active    BOOLEAN,
  created   DATE,
  seen_at   TIMESTAMP,
  tags      ARRAY<STRING>,
  attrs     MAP<STRING,STRING>,
  location  STRUCT<city:STRING, zip:INT>
);

INSERT INTO types_demo
SELECT 1, 'meter-A', 19.90, true, DATE '2026-01-15', TIMESTAMP '2026-01-15 10:30:00',
       array('indoor','smart'), map('vendor','x','fw','1.2'), named_struct('city','Vienna','zip',1010);

SELECT id, tags[0], attrs['vendor'], location.city FROM types_demo;
```

---

## 2. Tables

```sql
SHOW TABLES;
DESCRIBE types_demo;

CREATE TABLE readings (meter_id STRING, ts TIMESTAMP, kwh DOUBLE)
STORED AS ORC;

CREATE EXTERNAL TABLE readings_ext LIKE readings;   -- same schema, external
```

Managed vs. external: see [demos.md](demos.md) section 2.

---

## 3. INSERT, UPDATE, DELETE

```sql
INSERT INTO readings VALUES
  ('M1', '2026-01-01 00:00:00', 1.5),
  ('M1', '2026-01-01 01:00:00', 2.0),
  ('M2', '2026-01-01 00:00:00', 0.7),
  ('M2', '2026-01-02 00:00:00', NULL);

UPDATE readings SET kwh = 0 WHERE kwh IS NULL;   -- managed (ACID) tables only
DELETE FROM readings WHERE meter_id = 'M2' AND kwh = 0;
```

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
       COUNT(*)  AS n,
       SUM(kwh)  AS total,
       AVG(kwh)  AS avg_kwh,
       MAX(kwh)  AS peak
FROM readings
GROUP BY meter_id
HAVING SUM(kwh) > 1;
```

---

## 6. Joins

```sql
CREATE TABLE meters (meter_id STRING, city STRING);
INSERT INTO meters VALUES ('M1','Vienna'), ('M3','Graz');

SELECT r.meter_id, m.city, r.kwh
FROM readings r
JOIN meters m ON r.meter_id = m.meter_id;          -- inner

SELECT m.meter_id, r.kwh
FROM meters m
LEFT JOIN readings r ON r.meter_id = m.meter_id;   -- M3 appears with NULL
```

---

## 7. Common functions

```sql
SELECT
  upper('abc'), concat('a','-','b'), substr('workshop',1,4),   -- strings
  round(3.14159, 2), floor(2.7), abs(-5),                      -- numbers
  current_date, year(ts), date_add(to_date(ts), 7),            -- dates
  CAST('42' AS INT),                                           -- casting
  COALESCE(kwh, 0),                                            -- NULL handling
  CASE WHEN kwh > 1.8 THEN 'high' ELSE 'normal' END AS level
FROM readings LIMIT 1;
```

---

## 8. Subquery, CTE, window function

```sql
WITH hourly AS (
  SELECT meter_id, ts, kwh FROM readings WHERE kwh IS NOT NULL
)
SELECT meter_id, ts, kwh,
       SUM(kwh) OVER (PARTITION BY meter_id ORDER BY ts) AS running_total,
       ROW_NUMBER() OVER (PARTITION BY meter_id ORDER BY kwh DESC) AS rank_in_meter
FROM hourly;
```

---

## 9. Complex types: explode

```sql
SELECT id, tag
FROM types_demo
LATERAL VIEW explode(tags) t AS tag;
```

---

## 10. Partitions

```sql
CREATE TABLE readings_part (meter_id STRING, kwh DOUBLE)
PARTITIONED BY (day STRING)
STORED AS ORC;

INSERT INTO readings_part PARTITION (day='2026-01-01') VALUES ('M1', 1.5), ('M2', 0.7);

SHOW PARTITIONS readings_part;
SELECT * FROM readings_part WHERE day = '2026-01-01';   -- partition pruning
```

---

## 11. Inspect and clean up

```sql
DESCRIBE FORMATTED readings;      -- location, format, owner, table type
EXPLAIN SELECT meter_id, SUM(kwh) FROM readings GROUP BY meter_id;
SHOW CREATE TABLE readings;

DROP DATABASE tour CASCADE;
```

---

## Timing hint

About 15 minutes. Skip sections 8–10 if short on time and point to the lab instead.
