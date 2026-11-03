-- I1-basics-ranger setup (run in Hue Hive editor as admin/trainer user)
-- Creates database cdp_workshop and its tables (shared with I2-basics-atlas, whose setup.hql
-- contains the same meter_readings definition). Do NOT create Ranger policies here;
-- the trainer adds them live during the lab.

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

CREATE TABLE IF NOT EXISTS cdp_workshop.customer_master (
  device_id STRING,
  customer_name STRING,
  iban_last4 STRING
);

CREATE TABLE IF NOT EXISTS cdp_workshop.station_assignment (
  user_name STRING,
  station_id STRING
);

-- Re-runnable: TRUNCATE keeps the table entities (Atlas tags, Ranger policies) and reloads the rows.
TRUNCATE TABLE cdp_workshop.meter_readings;
TRUNCATE TABLE cdp_workshop.customer_master;
TRUNCATE TABLE cdp_workshop.station_assignment;

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

INSERT INTO cdp_workshop.customer_master VALUES
  ('DEV-0001', 'Alex Meter', '4821'),
  ('DEV-0002', 'Blake Grid', '9033'),
  ('DEV-0101', 'Evan Load', '1144'),
  ('DEV-0201', 'Ivy Sub', '5560'),
  ('DEV-0301', 'Morgan Tie', '7782');

-- station_assignment: each participant gets 2 neighbouring stations (rotating over
-- TS-101, TS-102, TS-305, TS-401), for participant01..participant20.
-- EDIT user names if your real participants differ.
INSERT INTO cdp_workshop.station_assignment VALUES
  ('participant01', 'TS-101'), ('participant01', 'TS-102'),
  ('participant02', 'TS-102'), ('participant02', 'TS-305'),
  ('participant03', 'TS-305'), ('participant03', 'TS-401'),
  ('participant04', 'TS-401'), ('participant04', 'TS-101'),
  ('participant05', 'TS-101'), ('participant05', 'TS-102'),
  ('participant06', 'TS-102'), ('participant06', 'TS-305'),
  ('participant07', 'TS-305'), ('participant07', 'TS-401'),
  ('participant08', 'TS-401'), ('participant08', 'TS-101'),
  ('participant09', 'TS-101'), ('participant09', 'TS-102'),
  ('participant10', 'TS-102'), ('participant10', 'TS-305'),
  ('participant11', 'TS-305'), ('participant11', 'TS-401'),
  ('participant12', 'TS-401'), ('participant12', 'TS-101'),
  ('participant13', 'TS-101'), ('participant13', 'TS-102'),
  ('participant14', 'TS-102'), ('participant14', 'TS-305'),
  ('participant15', 'TS-305'), ('participant15', 'TS-401'),
  ('participant16', 'TS-401'), ('participant16', 'TS-101'),
  ('participant17', 'TS-101'), ('participant17', 'TS-102'),
  ('participant18', 'TS-102'), ('participant18', 'TS-305'),
  ('participant19', 'TS-305'), ('participant19', 'TS-401'),
  ('participant20', 'TS-401'), ('participant20', 'TS-101');

-- Sanity check
SELECT COUNT(*) AS meter_readings_rows FROM cdp_workshop.meter_readings;
