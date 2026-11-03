-- I1-basics-ranger setup verification (run in Hue). Not checked: Ranger policies.

SHOW DATABASES LIKE 'cdp_workshop';                                   -- expect: cdp_workshop

SELECT 'meter_readings'    AS tbl, COUNT(*) AS cnt, 30 AS expected FROM cdp_workshop.meter_readings
UNION ALL
SELECT 'customer_master'   AS tbl, COUNT(*) AS cnt, 5  AS expected FROM cdp_workshop.customer_master
UNION ALL
SELECT 'station_assignment' AS tbl, COUNT(*) AS cnt, 2 AS expected FROM cdp_workshop.station_assignment;
-- station_assignment: cnt must be >= expected (2 rows per participant)
