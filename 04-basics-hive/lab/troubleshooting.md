# Hive lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal provided by your instructor (`user@REALM`).

## Beeline: `GSS initiate failed` or `Could not open client transport`

- Run `klist`. No valid ticket means `kinit "${WORKSHOP_USER}"` again.  
- Start Beeline with the command from [lab section 0](lab_basics_hive.md#0-orient--connect-and-create-your-database) (no `-u` URL — the edge node is preconfigured).  
- Still failing: ask your instructor whether HiveServer2 is up.

## `${ws_user}` shows up literally in an error (Beeline)

You started Beeline without the `--hivevar` options. Quit (`!quit`) and start it again with the command from [lab section 0](lab_basics_hive.md#0-orient--connect-and-create-your-database). Variables only exist in the session you started them in.

## Hue: asks for a value again, or the query fails with an empty or wrong path

The variables belong to the editor tab. Fill in the `ws_user` field below the editor again (a new tab or a reloaded page starts empty), and check them with the test statement from the [Hue section of the lab](lab_basics_hive.md#optional--use-hue-instead-of-beeline-and-hdfs). A typo in `ws_user` shows up as a wrong database name.

## `Table not found` or `Database does not exist`

Your Beeline session lost its database. Run `USE ws_<your_username>;` (or start Beeline again, which resets it). `SHOW TABLES;` tells you what exists.

## `Table already exists`

You ran a `CREATE` twice. Drop the table and create it again — for an **external** table the files stay:

```sql
DROP TABLE meter_orc;
```

If a table sits on top of files you want to start over with, also remove the files in that table's folder with `hdfs dfs -rm -skipTrash "${HIVE_EXT}/<table>/*"` (the folder itself belongs to the table).

## `Permission denied: user=hive, access=WRITE, inode=…`

You cannot write into the table folder under `HIVE_EXT` (for example `hdfs dfs -cp` fails with permission denied). Check with `hdfs dfs -ls -d "${HIVE_EXT}"` that the folder exists and that `WORKSHOP_USER` is your own name, then ask your instructor — an HDFS policy for the workshop users on `{USER}` folders is missing. Trainers: see [ranger README](../../00-setup/admin/ranger/README.md).

## `user … does not have [ALL] privilege on [hdfs://…]` or `[CREATE] on [ws_<your_username>…]`

Ranger does not allow your user to create objects in that database. Check that the database is named `ws_<your_username>` and ask your instructor — a Hive policy for the workshop group is missing. Trainers: see [ranger README](../../00-setup/admin/ranger/README.md), section module 04.

## CTAS with `CREATE EXTERNAL TABLE … AS SELECT` is rejected

Some Hive versions do not allow `AS SELECT` for external tables. Create the table with the column list and fill it with an insert instead:

```sql
CREATE EXTERNAL TABLE meter_orc (
  ts_utc STRING, station_id STRING, active_power_kw DOUBLE, reactive_power_kvar DOUBLE,
  voltage_v DOUBLE, current_a DOUBLE, transformer_load_pct DOUBLE,
  quality_flag STRING, event_code STRING, comm_status STRING
) STORED AS ORC;
INSERT INTO meter_orc SELECT * FROM meter_csv;
```

Do the same for `meter_parquet` with `STORED AS PARQUET`. Everything after that works unchanged.

## `FAILED: SemanticException … Attempt to do update or delete on table … that is not transactional`

Expected in [lab section 5](lab_basics_hive.md#5-update-and-delete-on-external-tables). External tables cannot be updated or deleted row by row. In section 7 the same statements work on the managed table `landisgyr_managed`. If you get this error in section 7, check with `DESCRIBE FORMATTED landisgyr_managed;` that `Table Type` is `MANAGED_TABLE` and `transactional` is `true`.

## All columns are `NULL`

The columns of the table do not match the file. Check the order and types with `DESCRIBE landisgyr_csv;` and compare with the first lines of the CSV. In the partitioned tables the file must **not** contain the partition column — compare with [section 3](lab_basics_hive.md#3-partitions--add-partition-and-msck-repair).

## First row of the table is the CSV header (or missing)

The table property `skip.header.line.count` is set to skip one line **per file**. Tables on shared CSVs need it; tables on files that Hive wrote itself (`meter_csv`) must not have it.

## `SHOW PARTITIONS` is empty or `MSCK REPAIR` adds nothing

- Folder names must look exactly like `station_id=TS-101` (no spaces, correct spelling).  
- The folders must be **inside** the table folder (`${HIVE_EXT}/landisgyr_by_station`).  
- Check with `hdfs dfs -ls -R "${HIVE_EXT}/landisgyr_by_station"`.

## `hive: command not found` (`orcfiledump`)

The Hive client is not on your `PATH` on this edge node. Ask your instructor for the right client path. You can finish the lab without it — skip the `orcfiledump` command and compare the file sizes from `hdfs dfs -du -h`.

## `strings: command not found`

Replace the last command in [lab section 4](lab_basics_hive.md#4-file-formats--csv-orc-parquet-on-hdfs) with:

```bash
hdfs dfs -cat "<parquet-file>" | tail -c 2000 | tr -c '[:print:]' '.'
```

## Query hangs in `Reducer 2 … INITED` or the first query is slow

The first query in a session can take up to a minute while a Tez session starts. If a query waits much longer, YARN has no free capacity for your queue: see the [YARN lab troubleshooting](../../03-basics-yarn/lab/troubleshooting.md) (`yarn queue -status`).

## `MERGE` fails with a cardinality violation

More than one source row matched the same target row. Check `landisgyr_changes` — you should have exactly two data rows (and one header). Look for a second file in `${HIVE_EXT}/landisgyr_changes`.

## Your username contains `-` or `.`

Database names with special characters need backticks. Use ``USE `ws_<your_username>`;`` and ask your instructor for help with `CREATE DATABASE`.
