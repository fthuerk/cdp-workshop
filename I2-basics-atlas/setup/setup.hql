-- I2-basics-atlas setup (run in Hue Hive editor as admin/trainer user)
-- Makes sure the shared table cdp_workshop.meter_readings exists. It is the same table, with
-- the same 30 rows, that I1-basics-ranger/setup/setup.hql creates, so you can run either file
-- first. Re-running keeps the table entity (and the Atlas tags on it); rows are reloaded.
-- Afterwards the trainer attaches the Atlas classification PII to the columns
-- customer_name and customer_email of this table (see setup.md). Do NOT create Ranger policies here.

CREATE DATABASE IF NOT EXISTS cdp_workshop;

CREATE TABLE IF NOT EXISTS cdp_workshop.meter_readings (
  ts_utc STRING,
  station_id STRING,
  device_id STRING,
  customer_name STRING,
  customer_email STRING,
  region STRING,
  active_power_kw DOUBLE
);

TRUNCATE TABLE cdp_workshop.meter_readings;

-- Synthetic meter readings (30 rows, 4 stations)
INSERT INTO cdp_workshop.meter_readings VALUES
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0001', 'Alex Meter', 'alex.meter@example.com', 'North', 12.4),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0001', 'Alex Meter', 'alex.meter@example.com', 'North', 13.1),
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0002', 'Blake Grid', 'blake.grid@example.com', 'North', 8.7),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0002', 'Blake Grid', 'blake.grid@example.com', 'North', 9.2),
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0003', 'Casey Volt', 'casey.volt@example.com', 'North', 10.1),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0003', 'Casey Volt', 'casey.volt@example.com', 'North', 10.4),
  ('2024-01-01 00:00:00', 'TS-101', 'DEV-0004', 'Dana Amp', 'dana.amp@example.com', 'North', 11.0),
  ('2024-01-01 00:15:00', 'TS-101', 'DEV-0004', 'Dana Amp', 'dana.amp@example.com', 'North', 11.3),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0101', 'Evan Load', 'evan.load@example.com', 'East', 14.2),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0101', 'Evan Load', 'evan.load@example.com', 'East', 14.8),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0102', 'Fran Peak', 'fran.peak@example.com', 'East', 16.1),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0102', 'Fran Peak', 'fran.peak@example.com', 'East', 15.9),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0103', 'Glen Sync', 'glen.sync@example.com', 'East', 13.5),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0103', 'Glen Sync', 'glen.sync@example.com', 'East', 13.7),
  ('2024-01-02 00:00:00', 'TS-102', 'DEV-0104', 'Hope Line', 'hope.line@example.com', 'East', 12.9),
  ('2024-01-02 00:15:00', 'TS-102', 'DEV-0104', 'Hope Line', 'hope.line@example.com', 'East', 13.0),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0201', 'Ivy Sub', 'ivy.sub@example.com', 'South', 21.5),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0201', 'Ivy Sub', 'ivy.sub@example.com', 'South', 20.9),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0202', 'Jade Ring', 'jade.ring@example.com', 'South', 22.3),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0202', 'Jade Ring', 'jade.ring@example.com', 'South', 22.0),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0203', 'Kai Feed', 'kai.feed@example.com', 'South', 19.8),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0203', 'Kai Feed', 'kai.feed@example.com', 'South', 20.1),
  ('2024-01-03 00:00:00', 'TS-305', 'DEV-0204', 'Lane Bus', 'lane.bus@example.com', 'South', 18.6),
  ('2024-01-03 00:15:00', 'TS-305', 'DEV-0204', 'Lane Bus', 'lane.bus@example.com', 'South', 18.9),
  ('2024-01-04 00:00:00', 'TS-401', 'DEV-0301', 'Morgan Tie', 'morgan.tie@example.com', 'West', 9.4),
  ('2024-01-04 00:15:00', 'TS-401', 'DEV-0301', 'Morgan Tie', 'morgan.tie@example.com', 'West', 9.6),
  ('2024-01-04 00:00:00', 'TS-401', 'DEV-0302', 'Noel Arc', 'noel.arc@example.com', 'West', 10.2),
  ('2024-01-04 00:15:00', 'TS-401', 'DEV-0302', 'Noel Arc', 'noel.arc@example.com', 'West', 10.5),
  ('2024-01-04 00:00:00', 'TS-401', 'DEV-0303', 'Owen Pole', 'owen.pole@example.com', 'West', 11.7),
  ('2024-01-04 00:15:00', 'TS-401', 'DEV-0303', 'Owen Pole', 'owen.pole@example.com', 'West', 11.9);

-- Sanity check: expect 30
SELECT COUNT(*) AS meter_readings_rows FROM cdp_workshop.meter_readings;
