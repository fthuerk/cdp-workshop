# Troubleshooting — Lakehouse (Iceberg)

For Kerberos, Hue, and Ranger basics see the [Hive troubleshooting](../../04-basics-hive/lab/troubleshooting.md); for `impala-shell` and Impala see the [Impala module](../../06-basics-impala/README.md) (same errors, same fixes).

## `Table does not exist: landisgyr_changes` (or `stations`, `market_prices`, `landisgyr_csv`)

The source tables of lab section 0 are missing or you are in another database. Run `USE ws_<your_user>;` (or pick the database in Hue) and the section 0 block again — it is safe to repeat.

## Source tables are empty

The CSV files were not copied into the table folders, or Impala has not seen them yet. Check `hdfs dfs -ls "${HIVE_EXT}/landisgyr_csv"`, copy the files again, and run `REFRESH landisgyr_csv;`.

## Hue asks for a value or shows `${ws_user}` in an error

The placeholder has no value. Type your `WORKSHOP_USER` into the `ws_user` input field below the editor. The same applies to `snap_first`, `snap_now`, and `snap_good`: paste the snapshot ID from the result of the query that the lab names.

## `CREATE EXTERNAL TABLE … STORED AS ICEBERG` is denied or fails with an authorization error

Iceberg needs **two** Ranger policies: the usual Hive table policy on `ws_*`, and the Hadoop SQL **storage handler** policy (storage-type `iceberg`, storage-url `*`, permission *RW Storage*) for the workshop users. A missing second policy shows up when you create or alter an Iceberg table. Trainers: see the [ranger README](../../00-setup/admin/ranger/README.md), section module 07.

## `UPDATE` / `DELETE` / `MERGE` fails on `ice_meter` with a message about the format version or row-level operations

The table was created as format version 1. Check with `SHOW TBLPROPERTIES ice_meter;` that `format-version` is `2`. Drop the table (`DROP TABLE ice_meter;`, then remove leftover files in its folder) and create it again with the statement of section 2. Some versions also allow `ALTER TABLE ice_meter SET TBLPROPERTIES ('format-version'='2');` — a downgrade is never possible.

## `UPDATE` / `MERGE` is not supported

Impala `UPDATE` and `MERGE` need Cloudera Runtime **7.3.1.500 or later**; check the release notes for `DELETE` on older releases. Ask your instructor which version the cluster runs.

## `.snapshots`, `.files`, or `.history` is not found

Impala metadata tables need the full name: `ws_<your_user>.ice_meter.snapshots` — database, table, metadata table. In Hue use `ws_${ws_user}.ice_meter.snapshots`. If your release does not support them, use `DESCRIBE HISTORY ice_meter;` and `SHOW FILES IN ice_meter;`.

## `snap_first` (or `snap_now`, `snap_good`) is empty or wrong

The ID must come from the snapshot query of the section (`… FROM ws_${ws_user}.ice_meter.snapshots …`). Copy only the number, without spaces. IDs are long (19 digits); check the last digits.

## `Cannot find snapshot` / time travel fails

The snapshot was expired (lab section 7) or the ID was copied wrongly. List the IDs again with `SELECT snapshot_id, committed_at FROM ws_<user>.ice_meter.snapshots;` — after `EXPIRE_SNAPSHOTS` only the current snapshot is left.

## `EXPIRE_SNAPSHOTS` removed nothing

The timestamp is compared as UTC. If the session time zone is ahead of or behind UTC, `now()` can be earlier than the commits of the last hours. Use `now() + INTERVAL 2 HOURS` for the lab. Also note that the table property `history.expire.min-snapshots-to-keep` can keep snapshots.

## `INSERT OVERWRITE` into `meter_part` fails

Impala cannot write ORC. The lab table is `STORED AS PARQUET`; if you created `meter_part` differently, drop it and create it again. Also check that you have `rwx` on `${HIVE_EXT}/meter_part` (Ranger HDFS policy).

## `meter_part` shows no partitions after `RECOVER PARTITIONS`

The folder names must be exactly `station_id=TS-204`. Check with `hdfs dfs -ls "${HIVE_EXT}/meter_part"`.

## Range join is very slow or rejected

The join has no equality condition and runs as a Cartesian product. Keep the equality on `station_id` or on the date as in lab section 6 and let the range condition filter within it.

## `MERGE` fails with a cardinality violation

More than one source row matched the same target row. Check `SELECT * FROM landisgyr_changes;` — exactly four data rows with different keys.
