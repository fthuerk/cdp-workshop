# Spark lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal from your instructor (`user@REALM`).

## `pyspark: command not found` or wrong Spark version

Use the PySpark binary from your handout (`pyspark3`, `/opt/cloudera/parcels/.../bin/pyspark`, etc.). The lab assumes Spark 3 on CDP.

## `AnalysisException: Path does not exist` or `Unable to infer schema`

- Check `echo "${METER_CSV}"` and `hdfs dfs -ls "${METER_CSV}"`.  
- Adjust `WORKSHOP_ROOT` if your workshop path differs.  
- If bootstrap never ran, ask your instructor to run `00-setup/admin/bootstrap.sh`.

## Application stays `ACCEPTED` or at 0% on YARN

The job is waiting for containers — often memory or queue limits (same idea as the YARN basics lab optional section). Lower `--executor-memory` only for the deliberate demo in section 8; for normal runs use cluster defaults.

## `Container killed by YARN … exceeding memory limits`

Section 8 uses a tiny `--executor-memory` on purpose. For real jobs, increase executor memory or reduce shuffle partition count.

## `org.apache.hadoop.mapreduce.fileoutput.FileOutputCommitter … already exists`

You wrote to an HDFS path without `mode("overwrite")`. Remove the path (`hdfs dfs -rm -r …`) or use `.mode("overwrite")` as in section 5.

## `FileNotFoundException: File file:/tmp/spark_cleanse_join.py does not exist`

You submitted a **local** script path without copying the file to that node first. Use the `hdfs dfs -get` step in section 6, or submit with an `hdfs://` URI to `${SPARK_LAB}/assets/spark_cleanse_join.py`.

## `Permission denied` on HDFS write under `/user/...`

Your Kerberos user must own `${WORKSHOP_HOME}`. Ask your instructor if your home directory is missing.

## Beeline / Metastore section 7: `GSS initiate failed`

Verify `HS2_URL` from your handout and a valid ticket (`klist`).

## Ranger: `does not have privilege` on `{USER}` or HDFS

Workshop users need Hive policies on database `{USER}` (same pattern as the Hive basics module) and HDFS write on your `/user/<name>` path. Ask your instructor.

## Self-check: row count not 24 or 12

- **24 joined rows:** inner join on `ts_utc` only — each of 12 OK meter rows matches two weather stations. Redo sections 2 and 4.  
- **12 cleansed rows:** three WARN rows in the sample must be filtered out in section 2.  
- Missing `_SUCCESS` on `spark-batch-curated`: redo section 6 and wait until YARN shows `FINISHED`.  
- Missing shared script: instructor runs `./06-basics-spark/setup/setup.sh`.
