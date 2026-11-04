# Data types lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal from your instructor (`user@REALM`).

## Impala: `Could not resolve table reference: 'edge_values'` or empty database list

- Run `USE <your_user>;` in the Impala editor.  
- You created the table in Hive: run `INVALIDATE METADATA;` (all tables) or `INVALIDATE METADATA edge_values;` in Impala.  
- If you still see no table, repeat the `CREATE EXTERNAL TABLE` from section 1 in Hive.

## Spark: `Table or view not found: edge_values`

You did not select your database. Run `q(f"USE {db}")` again, or use `spark.sql("SELECT * FROM <your_user>.edge_values")`. If the shell was restarted, repeat the setup lines from section 0.

## Table exists but `SELECT COUNT(*)` returns 0 or 7

- 0 rows: the CSV is not in `${TYPES_EXT}/edge_values`. Redo the `hdfs dfs -cp -f` from section 1 and, in Impala, `REFRESH edge_values;`.  
- 7 rows: the header line is counted. Re-create the table with `TBLPROPERTIES ('skip.header.line.count'='1')` (`DROP TABLE edge_values;` first; the external file stays).

## `Permission denied` when copying the CSV or creating the table

The table data must live in the default external folder `${TYPES_EXT}/edge_values` — do not create tables with a custom `LOCATION`. If the copy itself is denied, ask your instructor to check HDFS access on `${TYPES_EXT}` and read access on `${TYPES_LAB}/edge`.

## Ranger: `does not have privilege` on database, table or HDFS path

Same policies as the Hive and Impala modules: `{USER}` database/table privileges and read/write on `/warehouse/tablespace/external/hive/{USER}.db`. Spark needs the same access. Ask your instructor.

## Errors for some functions or casts in sections 2–5

**Expected.** `Undefined function`, `Unknown function` and failed casts are part of the comparison. Write them down instead of fixing them.

## `Table already exists` for the views or `kw_to_mw` not found

- Views: they are created with `IF NOT EXISTS`; to change one, `DROP VIEW probe_hive;` first.  
- `kw_to_mw` exists only in the `pyspark3` session where you registered it. Register it again after a restart, or after `exit()`.

## Self-check: row count not 6

Redo section 1 (copy and table definition). Missing `${TYPES_LAB}/edge/edge-values.csv`: your instructor runs `./14-basics-datatypes/setup/setup.sh`.
