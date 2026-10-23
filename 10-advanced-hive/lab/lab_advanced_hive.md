# Advanced Hive hands-on lab

Run sections in order. You need one terminal on the edge node with `beeline`; the second terminal is only used once, to copy the sample files. This lab is about the **complex operations and functions** of Hive SQL on the smart-meter data: joins beyond the basic inner join, window functions, complex types, grouping sets, and geo data as WKT.

Set your Kerberos identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`. `HIVE_EXT` is the folder where Hive keeps the data of your external tables (one sub-folder per table, created by Hive). `HS2_URL` is the HiveServer2 JDBC URL from your workshop handout.

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export HIVE_EXT="/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db"   # adjust if needed
export HS2_URL="<jdbc-url-from-your-handout>"
```

The lab expects everyday SQL (`WHERE`, `GROUP BY`, `CASE`, views, a basic `JOIN`). Section 0 creates everything it needs and you can repeat it at any time, so you can start here without any other lab.

---

## 0. Prepare — database, tables, and a view

**Goal:** Create the four small tables and the view that all following sections use.

Start Beeline. The `--hivevar` option defines the variable `${ws_user}` that the SQL below uses (in Hue the same placeholder becomes an input field):

```bash
beeline -u "${HS2_URL}" \
  --hivevar ws_user="${WORKSHOP_USER}"
```

Create your database (if it does not exist yet) and the four external tables: meter readings, station reference data, hourly market prices, and operator weather. All fields are read by position, and the header line is skipped:

```sql
CREATE DATABASE IF NOT EXISTS ${ws_user};
USE ${ws_user};

CREATE EXTERNAL TABLE IF NOT EXISTS landisgyr_csv (
  ts_utc STRING, station_id STRING, device_id STRING, phase STRING,
  active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE,
  current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE,
  transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, comm_status STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS stations (
  station_id STRING, latitude DOUBLE, longitude DOUBLE,
  municipality STRING, district STRING, basemap_tile_hint STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS market_prices (
  timestamp_start STRING, timestamp_end STRING, market STRING,
  price_eur_mwh DOUBLE, price_ct_kwh DOUBLE, currency STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE EXTERNAL TABLE IF NOT EXISTS weather_operator (
  ts_utc STRING, station_id STRING, station_name STRING, temperature_c DOUBLE,
  relative_humidity_pct DOUBLE, wind_speed_mps DOUBLE, precipitation_mm DOUBLE,
  pressure_hpa DOUBLE, quality_flag STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');
```

Copy one shared CSV into each table folder. `-f` overwrites a file that is already there, so you can repeat this step:

```bash
# meter readings and station reference data
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "${HIVE_EXT}/landisgyr_csv/"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/basemap/sample-basemap-at-locations.csv" "${HIVE_EXT}/stations/"

# market prices and operator weather
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/awattar/sample-awattar-prices.csv" "${HIVE_EXT}/market_prices/"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv" "${HIVE_EXT}/weather_operator/"
```

The timestamps are text like `2026-01-15T08:00:00Z`, and an empty event code is an empty string. A view converts both once, so the following sections stay short:

```sql
CREATE OR REPLACE VIEW landisgyr_v AS
SELECT CAST(REPLACE(SUBSTR(ts_utc, 1, 19), 'T', ' ') AS TIMESTAMP) AS ts,
       station_id, device_id, phase, active_power_kw, reactive_power_kvar,
       voltage_v, current_a, power_factor, frequency_hz, transformer_load_pct,
       quality_flag, NULLIF(event_code, '') AS event_code, comm_status
FROM landisgyr_csv;

SELECT * FROM landisgyr_v LIMIT 5;
SELECT COUNT(*) FROM landisgyr_v;
```

You should see fifteen readings: five for each of the stations `TS-101`, `TS-204`, and `TS-305`.

---

## 1. Complex joins

**Goal:** Use the join types beyond the basic inner join, and spot a join that multiplies rows.

**Left join as anti-join.** Which stations never reported a `WARN`? Keep all stations, attach the ones with warnings, and keep the rows where nothing matched:

```sql
SELECT s.station_id, s.district
FROM stations s
LEFT JOIN (SELECT DISTINCT station_id FROM landisgyr_v WHERE quality_flag = 'WARN') w
  ON s.station_id = w.station_id
WHERE w.station_id IS NULL;
```

**Semi-join.** The opposite question needs no join output at all: which stations did report a `WARN`? `LEFT SEMI JOIN` (or `EXISTS`) only filters the left side and never repeats a row, however many matches there are:

```sql
SELECT s.station_id, s.district
FROM stations s
LEFT SEMI JOIN landisgyr_v m
  ON s.station_id = m.station_id AND m.quality_flag = 'WARN';

SELECT s.station_id, s.district
FROM stations s
WHERE EXISTS (SELECT 1 FROM landisgyr_v m WHERE m.station_id = s.station_id AND m.quality_flag = 'WARN');
```

**Join on a derived key.** Meter readings arrive every 15 minutes, prices per hour. Join on the hour — the first 13 characters of both timestamps (`2026-01-15T08`) — to estimate the energy cost per station (15 minutes = 0.25 h; prices are in ct/kWh):

```sql
SELECT m.station_id,
       ROUND(SUM(m.active_power_kw * 0.25), 1) AS energy_kwh,
       ROUND(SUM(m.active_power_kw * 0.25 * p.price_ct_kwh) / 100, 2) AS cost_eur
FROM landisgyr_csv m
JOIN market_prices p ON SUBSTR(m.ts_utc, 1, 13) = SUBSTR(p.timestamp_start, 1, 13)
GROUP BY m.station_id
ORDER BY cost_eur DESC;
```

**Self join with a non-equi condition.** Compare every station with every other one, once per pair. Hive accepts a condition other than `=` in an inner join, but it cannot use a plain shuffle join for it, so keep such joins to small tables:

```sql
SELECT a.station_id AS station_a, b.station_id AS station_b,
       ABS(a.latitude - b.latitude) AS delta_lat
FROM stations a
JOIN stations b ON a.station_id < b.station_id;
```

You should get three pairs for three stations.

**A join that multiplies rows.** Join the readings to the operator weather on the timestamp only and compare the row counts:

```sql
SELECT COUNT(*) FROM landisgyr_csv;
SELECT COUNT(*) FROM landisgyr_csv m JOIN weather_operator w ON m.ts_utc = w.ts_utc;
```

You should see twice as many rows after the join. Find out why, then fix it by averaging the weather per timestamp first, in a common table expression (`WITH`):

```sql
SELECT ts_utc, COUNT(*) AS weather_rows FROM weather_operator GROUP BY ts_utc;

WITH weather AS (
  SELECT ts_utc, ROUND(AVG(temperature_c), 2) AS avg_temp_c
  FROM weather_operator
  GROUP BY ts_utc
)
SELECT m.station_id, m.ts_utc, m.transformer_load_pct, w.avg_temp_c
FROM landisgyr_csv m
JOIN weather w ON m.ts_utc = w.ts_utc
ORDER BY m.station_id, m.ts_utc;
```

**Check question:** Why did the join double the rows? What do you check about the join keys before you trust a join result in a pipeline? Why is the cost query above only an estimate?

---

## 2. Window functions

**Goal:** Rank, compare, and accumulate rows within a group without collapsing them like `GROUP BY` does.

A window function adds a value to **every row** and computes it over a window of related rows: `PARTITION BY` defines the groups, `ORDER BY` the order inside a group. Start with ranking. Rank the readings of each station by transformer load, rounded to tens so that some readings tie:

```sql
SELECT station_id, ts, transformer_load_pct,
       ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY ROUND(transformer_load_pct, -1) DESC) AS row_nr,
       RANK()       OVER (PARTITION BY station_id ORDER BY ROUND(transformer_load_pct, -1) DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY station_id ORDER BY ROUND(transformer_load_pct, -1) DESC) AS dense_rnk
FROM landisgyr_v
ORDER BY station_id, row_nr;
```

You should see three rankings per row. They differ only on ties: `ROW_NUMBER` always counts on, `RANK` repeats the number and then skips, `DENSE_RANK` repeats it and does not skip. Look at a station with two readings in the same ten-percent step.

**Top-N per group.** A window function cannot be used in `WHERE`, so wrap it in a subquery. Find the highest-load reading of each station:

```sql
SELECT station_id, ts, transformer_load_pct, active_power_kw
FROM (
  SELECT station_id, ts, transformer_load_pct, active_power_kw,
         ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY transformer_load_pct DESC) AS rn
  FROM landisgyr_v
) ranked
WHERE rn = 1;
```

**Ranking aggregates.** The `OVER` clause can also follow an aggregate. Rank the stations by their peak load across all readings:

```sql
SELECT station_id,
       MAX(transformer_load_pct) AS max_load_pct,
       RANK() OVER (ORDER BY MAX(transformer_load_pct) DESC) AS load_rank
FROM landisgyr_v
GROUP BY station_id;
```

**Previous and next row.** `LAG` and `LEAD` read a neighbouring row of the same group. Compute how much the load changed since the previous reading — the first reading of every station has no predecessor, so it gets `NULL`:

```sql
SELECT station_id, ts, transformer_load_pct,
       LAG(transformer_load_pct) OVER (PARTITION BY station_id ORDER BY ts) AS prev_load_pct,
       ROUND(transformer_load_pct - LAG(transformer_load_pct) OVER (PARTITION BY station_id ORDER BY ts), 1) AS delta_pct
FROM landisgyr_v
ORDER BY station_id, ts;
```

**Running totals and moving averages.** A *frame* limits the window to rows around the current row. Accumulate the energy per station (15 minutes = 0.25 h) and smooth the load over the last three readings:

```sql
SELECT station_id, ts,
       ROUND(SUM(active_power_kw * 0.25) OVER (
         PARTITION BY station_id ORDER BY ts
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 1) AS energy_kwh_so_far,
       ROUND(AVG(transformer_load_pct) OVER (
         PARTITION BY station_id ORDER BY ts
         ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS load_avg_3
FROM landisgyr_v
ORDER BY station_id, ts;
```

The last reading of each station shows the total energy of the period; the moving average of the first row is just its own value.

**Buckets and share.** `NTILE` splits the rows into equally sized groups, `PERCENT_RANK` gives the relative position, and `SUM() OVER ()` without a partition gives a share of the total:

```sql
SELECT station_id, ts, active_power_kw,
       NTILE(3) OVER (ORDER BY active_power_kw) AS power_bucket,
       ROUND(PERCENT_RANK() OVER (ORDER BY active_power_kw), 2) AS power_pct_rank,
       ROUND(100 * active_power_kw / SUM(active_power_kw) OVER (), 1) AS share_of_total_pct
FROM landisgyr_v
ORDER BY active_power_kw;
```

**Check question:** What is the difference between `GROUP BY station_id` with `MAX(...)` and `MAX(...) OVER (PARTITION BY station_id)`? Which one would you use to flag every reading that is above 90 % of its station's peak?

---

## 3. Complex types and more functions

**Goal:** Pack rows into arrays, maps, and structs, unpack them again, and use the aggregation and string functions that Hive offers beyond `SUM` and `AVG`.

**Collect rows into arrays.** `collect_list` keeps every value, `collect_set` removes duplicates. List the event codes seen per station and the time of the warnings:

```sql
SELECT station_id,
       collect_set(event_code) AS event_codes,
       collect_list(CASE WHEN quality_flag = 'WARN' THEN date_format(ts, 'HH:mm') END) AS warn_times,
       COUNT(event_code) AS events
FROM landisgyr_v
GROUP BY station_id;
```

`NULL` values are skipped by both functions, which is why the `CASE` without an `ELSE` works as a filter. Arrays have their own functions:

```sql
SELECT station_id,
       size(collect_set(event_code)) AS distinct_events,
       array_contains(collect_set(event_code), 'HIGH_LOAD') AS had_high_load,
       sort_array(collect_set(event_code)) AS sorted_events
FROM landisgyr_v
GROUP BY station_id;
```

**Structs and maps.** `named_struct` groups several columns into one value and `map` creates key-value pairs. Build one value per reading that carries its key measurements:

```sql
SELECT station_id, ts,
       named_struct('kw', active_power_kw, 'load_pct', transformer_load_pct) AS measure,
       map('voltage_v', voltage_v, 'current_a', current_a) AS electrical
FROM landisgyr_v
LIMIT 5;
```

Access the parts with a dot for structs and brackets for maps:

```sql
SELECT station_id,
       m.measure.kw,
       m.electrical['voltage_v']
FROM (
  SELECT station_id,
         named_struct('kw', active_power_kw, 'load_pct', transformer_load_pct) AS measure,
         map('voltage_v', voltage_v, 'current_a', current_a) AS electrical
  FROM landisgyr_v
) m
LIMIT 5;
```

**Unpack with `LATERAL VIEW explode`.** `explode` turns an array or map into rows. Combine it with `LATERAL VIEW` to keep the other columns. Count the warnings per hour that you collected above:

```sql
SELECT t.station_id, w.warn_time
FROM (
  SELECT station_id,
         collect_list(CASE WHEN quality_flag = 'WARN' THEN date_format(ts, 'HH:mm') END) AS warn_times
  FROM landisgyr_v
  GROUP BY station_id
) t
LATERAL VIEW explode(t.warn_times) w AS warn_time;
```

A station without warnings has an empty array and therefore **disappears** from the result. `LATERAL VIEW OUTER explode(...)` keeps it with a `NULL`. Try it by adding `OUTER`.

**Subtotals with `GROUPING SETS`, `ROLLUP`, and `CUBE`.** One query can return several levels of aggregation. `ROLLUP` adds the subtotal per station and a grand total; `GROUPING__ID` tells you which level a row belongs to:

```sql
SELECT station_id, phase, COUNT(*) AS readings, ROUND(AVG(active_power_kw), 1) AS avg_kw,
       GROUPING__ID AS level_id
FROM landisgyr_v
GROUP BY station_id, phase WITH ROLLUP
ORDER BY level_id, station_id, phase;
```

The `NULL`s in `station_id` and `phase` mean "all". With `GROUPING SETS ((station_id), (quality_flag))` you pick the levels yourself, and `WITH CUBE` returns every combination.

**Statistical and string functions.** Fifteen rows are few, but the syntax is the same on millions. `percentile_approx` computes quantiles without sorting everything, `regexp_extract` and `split` take text apart, and `stack` turns columns into rows:

```sql
SELECT station_id,
       percentile_approx(active_power_kw, array(0.5, 0.9)) AS kw_median_p90,
       stddev_pop(active_power_kw) AS kw_stddev,
       corr(active_power_kw, transformer_load_pct) AS corr_kw_load
FROM landisgyr_v
GROUP BY station_id;

SELECT device_id,
       regexp_extract(device_id, '^LG-(TS-[0-9]+)-([A-Z])$', 1) AS station_from_device,
       split(device_id, '-')[3] AS meter_letter
FROM landisgyr_v
GROUP BY device_id;

SELECT m.station_id, s.measure, s.measure_value
FROM landisgyr_v m
LATERAL VIEW stack(2, 'voltage_v', m.voltage_v, 'current_a', m.current_a) s AS measure, measure_value
LIMIT 6;
```

**Check question:** `explode` and `GROUP BY`/`collect_list` are inverse operations. When would you store a table with arrays instead of one row per value — and what do you lose when you do?

---

## 4. Geo data as WKT

**Goal:** Build and read geometries as **WKT** (Well-Known Text) in plain Hive SQL, and use them to find the nearest station.

WKT is the standard text format for geometries: `POINT(16.4205 48.1731)`, `LINESTRING(…)`, or `POLYGON((…))`. Note the order: **longitude first, then latitude**. Hive has no geometry type; a WKT value is a plain `STRING` that GIS tools, QGIS, and spatial libraries understand. Build one WKT point per station from the coordinate columns:

```sql
SELECT station_id, municipality,
       CONCAT('POINT(', CAST(longitude AS STRING), ' ', CAST(latitude AS STRING), ')') AS wkt_point
FROM stations;
```

Combine the points of all stations into one `LINESTRING` and the bounding box of the stations into one `POLYGON`. The polygon ring must be closed — it ends with the coordinates it started with:

```sql
SELECT CONCAT('LINESTRING(',
         CONCAT_WS(', ', sort_array(collect_list(CONCAT(CAST(longitude AS STRING), ' ', CAST(latitude AS STRING))))),
       ')') AS wkt_line,
       CONCAT('POLYGON((',
         CAST(MIN(longitude) AS STRING), ' ', CAST(MIN(latitude) AS STRING), ', ',
         CAST(MAX(longitude) AS STRING), ' ', CAST(MIN(latitude) AS STRING), ', ',
         CAST(MAX(longitude) AS STRING), ' ', CAST(MAX(latitude) AS STRING), ', ',
         CAST(MIN(longitude) AS STRING), ' ', CAST(MAX(latitude) AS STRING), ', ',
         CAST(MIN(longitude) AS STRING), ' ', CAST(MIN(latitude) AS STRING),
       '))') AS wkt_bbox
FROM stations;
```

The points of the line are sorted as text, not along a route, so treat it as a demonstration of the format. Paste the result into a WKT viewer of your choice, for example a QGIS text layer or an online WKT map, to see the three stations and the box around them.

Now read the geometry back. Extract longitude and latitude from the WKT text with `regexp_extract`, and compute the distance between two points with the haversine formula (the great-circle distance on a sphere with radius 6371 km). Use the self join from section 1 to get every pair once:

```sql
WITH pts AS (
  SELECT station_id,
         CONCAT('POINT(', CAST(longitude AS STRING), ' ', CAST(latitude AS STRING), ')') AS wkt
  FROM stations
),
coords AS (
  SELECT station_id,
         CAST(regexp_extract(wkt, 'POINT\\(([-0-9.]+) ([-0-9.]+)\\)', 1) AS DOUBLE) AS lon,
         CAST(regexp_extract(wkt, 'POINT\\(([-0-9.]+) ([-0-9.]+)\\)', 2) AS DOUBLE) AS lat
  FROM pts
)
SELECT a.station_id AS station_a, b.station_id AS station_b,
       ROUND(2 * 6371 * ASIN(SQRT(
         POW(SIN(RADIANS(b.lat - a.lat) / 2), 2) +
         COS(RADIANS(a.lat)) * COS(RADIANS(b.lat)) * POW(SIN(RADIANS(b.lon - a.lon) / 2), 2)
       )), 2) AS distance_km
FROM coords a
JOIN coords b ON a.station_id < b.station_id
ORDER BY distance_km;
```

You should get three pairs with distances of a few kilometres.

**Nearest neighbour.** Combine the window function from section 2 with the distance: for every station, find the closest other station. A `JOIN` on `<>` gives every ordered pair, and `ROW_NUMBER` keeps the closest one:

```sql
WITH coords AS (
  SELECT station_id, longitude AS lon, latitude AS lat FROM stations
),
dist AS (
  SELECT a.station_id AS station_id, b.station_id AS nearest_station,
         2 * 6371 * ASIN(SQRT(
           POW(SIN(RADIANS(b.lat - a.lat) / 2), 2) +
           COS(RADIANS(a.lat)) * COS(RADIANS(b.lat)) * POW(SIN(RADIANS(b.lon - a.lon) / 2), 2)
         )) AS distance_km
  FROM coords a
  JOIN coords b ON a.station_id <> b.station_id
)
SELECT station_id, nearest_station, ROUND(distance_km, 2) AS distance_km
FROM (
  SELECT d.*, ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY distance_km) AS rn
  FROM dist d
) ranked
WHERE rn = 1;
```

**Optional — spatial functions.** The `ST_` functions of the ESRI spatial framework understand WKT directly. They exist only if your instructor registered them. Check with:

```sql
SHOW FUNCTIONS LIKE 'ST_*';
```

If you see functions like `ST_GeomFromText`, `ST_Point`, and `ST_Distance`, try them. `ST_Distance` returns the distance in degrees, not kilometres, so use it for comparing, not for measuring:

```sql
SELECT a.station_id, b.station_id,
       ST_Distance(ST_GeomFromText(CONCAT('POINT(', CAST(a.longitude AS STRING), ' ', CAST(a.latitude AS STRING), ')')),
                   ST_GeomFromText(CONCAT('POINT(', CAST(b.longitude AS STRING), ' ', CAST(b.latitude AS STRING), ')'))) AS distance_deg
FROM stations a
JOIN stations b ON a.station_id < b.station_id;
```

If the command returns nothing, skip this step: the haversine query above gives you the same ranking.

**Check question:** Why must WKT write longitude before latitude, and what goes wrong when you swap them? Why would the haversine join become a problem with 100,000 stations, and what would you do about it?

---

## Stretch (optional)

- Rank the **hours** of the day by market price with `RANK()` and join the result to the energy per hour of each station — which station used the most energy in the most expensive hour?
- Use `LAG` to flag every reading whose load jumped by more than 5 percentage points since the previous reading, and `collect_list` to list the flagged times per station.
- Clean up: `DROP VIEW landisgyr_v;` and `DROP TABLE` for the four tables; the files stay in `${HIVE_EXT}` because the tables are external — remove the table folders with `hdfs dfs -rm -r -skipTrash`.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket, `HS2_URL`, and your database):

```bash
./10-advanced-hive/lab/check.sh
```
