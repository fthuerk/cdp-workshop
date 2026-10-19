# Troubleshooting — Lakehouse (Iceberg)

For Kerberos, Beeline, Hue, and Ranger basics see the [Hive troubleshooting](../../04-basics-hive/lab/troubleshooting.md) (same errors, same fixes).

## `Table not found: landisgyr_changes` (or `stations`, `market_prices`, `landisgyr_csv`)

The source tables of lab section 0 are missing or you are in another database. Run `USE ws_${ws_user};` (Beeline) and the section 0 block again — it is safe to repeat. Empty results mean the CSV files were not copied into the table folders: `hdfs dfs -ls "${HIVE_EXT}/landisgyr_csv"`.

## `CREATE EXTERNAL TABLE … STORED BY ICEBERG` is denied or fails with an authorization error

Iceberg needs **two** Ranger policies: the usual Hive table policy on `ws_*`, and the Hadoop SQL **storage handler** policy (storage-type `iceberg`, storage-url `*`, permission *RW Storage*) for the workshop users. A missing second policy shows up when you create or alter an Iceberg table. Trainers: see the [ranger README](../../00-setup/admin/ranger/README.md), section module 07.

## `UPDATE` / `DELETE` / `MERGE` fails on `ice_meter` with a message about the format version or row-level operations

The table was created as format version 1 or without the properties of section 2. Check with `SHOW TBLPROPERTIES ice_meter;` that `format-version` is `2`. Drop the table (`DROP TABLE ice_meter;`, then remove leftover files in its folder) and create it again with the statement of section 2. Some versions also allow `ALTER TABLE ice_meter SET TBLPROPERTIES ('format-version'='2');` — a downgrade is never possible.

## Impala: `UPDATE` / `MERGE` is not supported, or the statement asks for Parquet

- Impala `UPDATE` and `MERGE` need Cloudera Runtime **7.3.1.500 or later**; check the release notes for `DELETE` on older releases. Ask your instructor which version the cluster runs.  
- Impala writes only Parquet delete files and only merge-on-read. Check `SHOW TBLPROPERTIES ice_meter;`: `write.format.default` and `write.delete.format.default` must be `parquet`, and the `write.*.mode` properties `merge-on-read` (the stretch task with copy-on-write sets them differently — set them back).

## Impala does not see the latest data, or the table does not exist

Impala caches table metadata. `INVALIDATE METADATA ice_meter;` for a table that was created in another engine, `REFRESH ice_meter;` after another engine committed a change.

## Spark: `UPDATE` / `MERGE` / `CALL` fails with a parse error (`mismatched input`)

The Iceberg SQL extensions are missing. Start the shell with `--conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions`, as in lab section 5.

## Spark: `Table or view not found: ice_meter.snapshots`

With the session catalog, metadata tables need the full name: `spark_catalog.<database>.ice_meter.snapshots`. In the lab the database is in the variable `db`.

## Spark does not show the latest commit from Hive or Impala

Spark caches Iceberg table metadata for a short time inside one session. Run the query again after about 30 seconds, or `spark.sql("REFRESH TABLE ice_meter")`.

## `SNAP_FIRST` (or `SNAP_NOW`, `SNAP_GOOD`) is empty

The helper commands in lab sections 6, 7, and 9 print nothing if Beeline failed. Run the `beeline` command without `| tail -1` to see the error. Typical causes: no Kerberos ticket (`klist`), `HS2_URL` not exported in this terminal, or the variables were set in a different terminal than the one running `hql`.

## `Cannot find snapshot` / time travel fails

The snapshot was expired (lab section 9) or the ID was copied wrongly. List the IDs again with `SELECT snapshot_id, committed_at FROM ws_<user>.ice_meter.snapshots;` — after `EXPIRE_SNAPSHOTS` only the current snapshot is left.

## `EXPIRE_SNAPSHOTS` removed nothing

The timestamp is compared as UTC. If the session time zone is behind UTC, `CURRENT_TIMESTAMP` can be earlier than the commits of the last hours. Use `CURRENT_TIMESTAMP + INTERVAL '2' HOUR` for the lab. Also note that the table property `history.expire.min-snapshots-to-keep` can keep snapshots.

## Range join or self join is very slow or rejected

The join has no equality condition and Hive refuses a Cartesian product, or it runs as one. Keep the equality on `station_id` or on the date as in lab section 8 and let the range condition filter within it.

## `The hive.auto.convert.join` plan shows no `Map Join Operator`

Statistics are missing, so Hive does not know that `stations` is small. Run `ANALYZE TABLE stations COMPUTE STATISTICS;` and explain again.

## `MERGE` fails with a cardinality violation

More than one source row matched the same target row. Check `SELECT * FROM landisgyr_changes;` — exactly two data rows. In Spark, check that the two source rows have different keys.
