# Hive lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal provided by your instructor (`user@REALM`).

## Beeline: `GSS initiate failed` or `Could not open client transport`

- Run `klist`. No valid ticket means `kinit "${WORKSHOP_USER}"` again.  
- Check `echo "${HS2_URL}"` — it must be the JDBC URL from your handout, including any `principal=…` part.  
- Still failing: ask your instructor whether HiveServer2 is up.

## `${hivevar:ws_user}` shows up literally in an error

You started Beeline without the `--hivevar` options. Quit (`!quit`) and start it again with the command from [lab section 0](lab.md#0-orient--connect-and-create-your-database). Variables only exist in the session you started them in.

## `Table not found` or `Database does not exist`

Your Beeline session lost its database. Run `USE ws_<your_username>;` (or start Beeline again, which resets it). `SHOW TABLES;` tells you what exists.

## `Table already exists`

You ran a `CREATE` twice. Drop the table and create it again — for an **external** table the files stay:

```sql
DROP TABLE meter_orc;
```

If a table sits on top of files you want to start over with, also remove the folder content with `hdfs dfs -rm -r -skipTrash` on that table's folder under `${HIVE_WORK}`.

## `Permission denied: user=hive, access=WRITE, inode=…`

HiveServer2 writes your table data as the `hive` service user, and it cannot write into your folder. Check that the folder is below `${HIVE_WORK}` (not your home) and ask your instructor to run the module setup again — it grants the `hive` user access to the shared work area. Trainers: see [setup/setup.sh](../setup/setup.sh).

## `user … does not have [ALL] privilege on [hdfs://…]` or `[CREATE] on [ws_…]`

Ranger does not allow your user to use that location or database. The location must be inside `${WORKSHOP_ROOT}`. Ask your instructor — a Ranger policy for the workshop group is missing. Trainers: see [ranger README](../../00-setup/admin/ranger/README.md), section module 03.

## `FAILED: SemanticException … Attempt to do update or delete on table … that is not transactional`

Expected in [lab section 5](lab.md#5-update-and-delete-on-external-tables). External tables cannot be updated or deleted row by row. In section 8 the same statements work on the managed table `landisgyr_managed`. If you get this error in section 8, check with `DESCRIBE FORMATTED landisgyr_managed;` that `Table Type` is `MANAGED_TABLE` and `transactional` is `true`.

## All columns are `NULL`

The columns of the table do not match the file. Check the order and types with `DESCRIBE landisgyr_csv;` and compare with the first lines of the CSV. In the partitioned tables the file must **not** contain the partition column — compare with [section 3](lab.md#3-partitions--add-partition-and-msck-repair).

## First row of the table is the CSV header (or missing)

The table property `skip.header.line.count` is set to skip one line **per file**. Tables on shared CSVs need it; tables on files that Hive wrote itself (`meter_csv`) must not have it.

## `SHOW PARTITIONS` is empty or `MSCK REPAIR` adds nothing

- Folder names must look exactly like `station_id=TS-101` (no spaces, correct spelling).  
- The folders must be **inside** the table `LOCATION` (`${HIVE_WORK}/landisgyr_by_station`).  
- Check with `hdfs dfs -ls -R "${HIVE_WORK}/landisgyr_by_station"`.

## `hive: command not found` (`orcfiledump`)

The Hive client is not on your `PATH` on this edge node. Ask your instructor for the right client path. You can finish the lab without it — skip the `orcfiledump` command and compare the file sizes from `hdfs dfs -du -h`.

## `strings: command not found`

Replace the last command in [lab section 4](lab.md#4-file-formats--csv-orc-parquet-on-hdfs) with:

```bash
hdfs dfs -cat "<parquet-file>" | tail -c 2000 | tr -c '[:print:]' '.'
```

## Query hangs in `Reducer 2 … INITED` or the first query is slow

The first query in a session can take up to a minute while a Tez session starts. If a query waits much longer, YARN has no free capacity for your queue: see the [YARN lab troubleshooting](../../02-basics-yarn/lab/troubleshooting.md) (`yarn queue -status`).

## `MERGE` fails with a cardinality violation

More than one source row matched the same target row. Check `landisgyr_changes` — you should have exactly two data rows (and one header). Look for a second file in `${HIVE_WORK}/landisgyr_changes`.

## Your username contains `-` or `.`

Database names with special characters need backticks. Use ``USE `ws_<your_username>`;`` and ask your instructor for help with `CREATE DATABASE`.
