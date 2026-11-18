# Troubleshooting — Lakehouse (Iceberg)

For Kerberos, Hue, and Ranger basics see the [Hive troubleshooting](../../04-basics-hive/lab/troubleshooting.md); for `impala-shell` and Impala see the [Impala module](../../05-basics-impala/README.md) (same errors, same fixes).

## `Table does not exist: grid_measurements_csv`

The source table of lab section 0 is missing or you are in another database. Run `USE <your_user>;` (or pick the database in Hue) and the section 0 block again — it is safe to repeat.

## Source table is empty

The CSV file was not copied into the table folder, or Impala has not seen it yet. Check `hdfs dfs -ls "${HIVE_EXT}/grid_measurements_csv"`, copy the file again, and run `REFRESH grid_measurements_csv;`.

## Hue asks for a value or shows `${ws_user}` in an error

The placeholder has no value. Type your `WORKSHOP_USER` into the `ws_user` input field below the editor. The same applies to `snap_first` and `snap_good`: paste the snapshot ID from the result of the query that the lab names.

## `CREATE TABLE … STORED BY ICEBERG` is denied or fails with an authorization error

Iceberg needs **two** Ranger policies: the usual Hive table policy on `{USER}`, and the Hadoop SQL **storage handler** policy (storage-type `iceberg`, storage-url `*`, permission *RW Storage*) for the workshop users. A missing second policy shows up when you create or alter an Iceberg table. Trainers: see the [ranger README](../../00-setup/admin/ranger/README.md), section module 07.

## `UPDATE` / `DELETE` / `MERGE` fails on `ice_meter` with a message about the format version or row-level operations

Format version 2 is the default, so the table is probably not an Iceberg table created with the statement of section 1 (for example created with `'format-version'='1'`). Check with `SHOW TBLPROPERTIES ice_meter;` that `format-version` is `2`. Drop the table (`DROP TABLE ice_meter;`, then remove leftover files in its folder) and create it again with the statement of section 1. Some versions also allow `ALTER TABLE ice_meter SET TBLPROPERTIES ('format-version'='2');` — a downgrade is never possible.

## `UPDATE` / `MERGE` is not supported

Impala `UPDATE` and `MERGE` need Cloudera Runtime **7.3.1.500 or later**; check the release notes for `DELETE` on older releases. Ask your instructor which version the cluster runs.

## `Table does not exist: grid_measurements_changes`

The change table of section 2 is missing or you are in another database. Run the `CREATE EXTERNAL TABLE` and `INSERT OVERWRITE` statements of section 2 again — they are safe to repeat.

## `MERGE` fails with a cardinality violation

More than one source row matched the same target row. Check `SELECT * FROM grid_measurements_changes;` — exactly four rows with different keys. Use `INSERT OVERWRITE` (not `INSERT INTO`) to fill the table, so a repeated run does not double the rows.

## `.snapshots`, `.files`, or `.history` is not found

Impala metadata tables need the full name: `<your_user>.ice_meter.snapshots` — database, table, metadata table. In Hue use `${ws_user}.ice_meter.snapshots`. `files` is a reserved word and needs backticks: ``${ws_user}.ice_meter.`files` ``. If your release does not support them, use `DESCRIBE HISTORY ice_meter;` and `SHOW FILES IN ice_meter;`.

## `snap_first` (or `snap_good`) is empty or wrong

The ID must come from the snapshot query of the section (`… FROM ${ws_user}.ice_meter.snapshots …`). Copy only the number, without spaces. IDs are long (19 digits); check the last digits.

## `Cannot find snapshot` / time travel fails

The snapshot was expired (lab section 4) or the ID was copied wrongly. List the IDs again with `SELECT snapshot_id, committed_at FROM <user>.ice_meter.snapshots;` — after `EXPIRE_SNAPSHOTS` only the current snapshot is left.

## `EXPIRE_SNAPSHOTS` removed nothing

The timestamp is compared as UTC. If the session time zone is ahead of or behind UTC, `now()` can be earlier than the commits of the last hours. Use `now() + INTERVAL 2 HOURS` for the lab. Also note that the table property `history.expire.min-snapshots-to-keep` can keep snapshots.
