-- I1-basics-ranger teardown (run in Hue as admin/trainer user)
-- Drops only the tables created by this module. The shared database cdp_workshop
-- is kept because other modules and demos (for example Atlas) reuse it.
-- NOTE: meter_readings is also the central table of I2-basics-atlas (with PII tags). Dropping it
-- removes those tags; skip this line if the Atlas lab still runs.
DROP TABLE IF EXISTS cdp_workshop.meter_readings;
DROP TABLE IF EXISTS cdp_workshop.customer_master;
DROP TABLE IF EXISTS cdp_workshop.station_assignment;
DROP TABLE IF EXISTS cdp_workshop.workshop_users;
-- Only at the very end of the whole workshop, if no other module uses it:
-- DROP DATABASE IF EXISTS cdp_workshop;

-- Afterwards remove or disable workshop policies on cdp_workshop in the Ranger UI.
