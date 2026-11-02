-- Workshop 08: load one landing folder as a partition and build a per-station summary.
-- Variables from the Oozie hive2 action: DB, INPUT_DIR, RUN_DATE.
-- Safe to run twice for the same RUN_DATE (INSERT OVERWRITE on one partition).

CREATE DATABASE IF NOT EXISTS ${DB};

CREATE EXTERNAL TABLE IF NOT EXISTS ${DB}.oozie_meter_landing (
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
PARTITIONED BY (load_date STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

ALTER TABLE ${DB}.oozie_meter_landing
  ADD IF NOT EXISTS PARTITION (load_date='${RUN_DATE}') LOCATION '${INPUT_DIR}';

CREATE TABLE IF NOT EXISTS ${DB}.oozie_station_summary (
  station_id STRING,
  readings BIGINT,
  avg_active_power_kw DOUBLE,
  max_load_pct DOUBLE
)
PARTITIONED BY (load_date STRING)
STORED AS ORC;

INSERT OVERWRITE TABLE ${DB}.oozie_station_summary PARTITION (load_date='${RUN_DATE}')
SELECT station_id,
       COUNT(*),
       ROUND(AVG(active_power_kw), 1),
       MAX(transformer_load_pct)
FROM ${DB}.oozie_meter_landing
WHERE load_date = '${RUN_DATE}'
  AND quality_flag = 'OK'
GROUP BY station_id;
