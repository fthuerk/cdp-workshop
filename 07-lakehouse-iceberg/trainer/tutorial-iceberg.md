# Iceberg guided tour — Impala, Hive, and Spark in CDP 7.3.2

Trainer-led run-through of Apache Iceberg beyond the participant lab. Part A holds the live demos (concurrency, compaction, governance, drop). Part B goes through the Iceberg functions the lab does not cover (schema and partition evolution, metadata tables, table properties, maintenance, branches and tags, migration). Part C shows the **same table from Impala, Hive, and Spark** and where the three engines behave differently on Cloudera Runtime 7.3.2.

Suggested flow: setup -> Part A demos (A1 after lab section 5, the rest as time allows) -> Part B functions (B1–B10, pick what the audience needs) -> Part C engines (C1–C6).

**Status:** not yet run end to end on the target cluster. Statements marked **(verify)** depend on the exact 7.3.2 build or service configuration; confirm them in a dry run and note the result in [notes.md](notes.md#pitfalls). The summary list is in [Version checklist](#version-checklist).

---

## Setup

Use your own `<trainer_user>` database. Two Hue Impala editor tabs (**A** and **B**) and one terminal for `hdfs`. For Part C you need additionally a Beeline session (Hive) and a `pyspark` session (Spark).

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
export HIVE_EXT="/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db"
```

```sql
-- Impala (Hue)
CREATE DATABASE IF NOT EXISTS ${ws_user};
USE ${ws_user};

CREATE TABLE demo_ice (id INT, name STRING, amount DOUBLE)
STORED BY ICEBERG;

INSERT INTO demo_ice VALUES (1, 'alpha', 10.0), (2, 'beta', 20.0), (3, 'gamma', 30.0);
```

---

# Part A — Live demos

Run **one section at a time** while participants watch. All demos use the throw-away table `demo_ice`.

## A1. Snapshot isolation — a long reader and a concurrent writer

**Goal:** Show that a running query keeps reading its snapshot while the table changes (lab section 5).

Make the reader slow so that you can change the table while it runs. The statement below adds a `sleep` per row; if it finishes too fast, insert the rows of `demo_ice` into itself several times first. In **tab A** start the slow query:

```sql
SELECT id, name, amount, sleep(20000) FROM demo_ice;
```

In **tab B** change the table while the query still runs:

```sql
UPDATE demo_ice SET amount = amount * 2;
SELECT * FROM demo_ice;
```

Tab B shows the doubled amounts immediately; tab A finishes with the **old** amounts. Run the query in tab A again: now the new values. Point out that no one waited for anyone.

## A2. Two writers — optimistic concurrency

**Goal:** Show what happens when two commits meet.

In tab A and B, start an `UPDATE` in both at about the same time, on the **same** rows (start the second one right after the first, or add `sleep` to the filter to widen the window):

```sql
UPDATE demo_ice SET name = concat(name, '-A') WHERE id = 1;
```

```sql
UPDATE demo_ice SET name = concat(name, '-B') WHERE id = 1;
```

Depending on timing, one statement succeeds and the other either retries (and succeeds with the updated state) or fails with a message that the table changed while the statement ran. Show both outcomes if you can, and `SELECT * FROM demo_ice;` — no lost update. Contrast: with `INSERT OVERWRITE` on an external table, the last writer silently wins.

Variation for Part C: run one writer in Impala and the other in Spark or Hive. The commit protocol is the same, so the conflict handling is too — the engines share the table, not a lock.

## A3. Files before and after compaction

**Goal:** Show why many small commits need maintenance.

Insert single rows, one statement each, and list the table folder:

```sql
INSERT INTO demo_ice VALUES (10, 'x', 1.0);
INSERT INTO demo_ice VALUES (11, 'x', 1.0);
INSERT INTO demo_ice VALUES (12, 'x', 1.0);
```

```bash
hdfs dfs -ls -R "${HIVE_EXT}/demo_ice/data"
```

Every statement added a Parquet file (and a metadata file and a snapshot). Compact and list again:

```sql
OPTIMIZE TABLE demo_ice;
```

Expire the old snapshots afterwards and show that the small files are gone:

```sql
ALTER TABLE demo_ice EXECUTE EXPIRE_SNAPSHOTS(now());
```

Point out that this is scheduled maintenance in production. If your release has no `OPTIMIZE TABLE`, show the file count and the expiry only, and do the compaction from Spark (section C5).

## A4. Same table, a Ranger audit

**Goal:** Show that Iceberg tables are governed by the same Ranger policies as any other table.

As a participant account without access to your `<trainer_user>` database, run `SELECT * FROM <trainer_user>.demo_ice;` in Hue (Impala). Open **Ranger → Audit** and find the denied request. A direct read of the files on HDFS is governed by the HDFS policy: show the HDFS audit entry too.

Then compare the engines (details in C6): Impala and Hive check the Hadoop SQL policy (and the Iceberg storage handler policy on `CREATE`/`ALTER`); Spark reads the files itself, so for Spark the HDFS/Ozone policy is what stops a participant **(verify)** whether column masking or row filtering of the Hadoop SQL policies applies in your Spark setup.

## A5. Drop

**Goal:** Contrast with plain external tables, where `DROP TABLE` keeps the files.

```sql
SHOW TBLPROPERTIES demo_ice;
DROP TABLE demo_ice;
```

```bash
hdfs dfs -ls "${HIVE_EXT}/demo_ice"
```

Check whether the table folder is still there (depends on `external.table.purge`) and remove it if needed. Repeat with a table created from Spark (`DROP TABLE` vs `DROP TABLE … PURGE`, section C6) to show that the **default differs between engines**. Re-create `demo_ice` (Setup) before continuing with Part B, or use the tables created there.

---

# Part B — More Iceberg functions

Part B uses a small table with a timestamp and a partition-friendly column. Run it in Impala unless a section says otherwise. Section C shows the same operations in the other engines.

```sql
CREATE TABLE ice_func (
  id INT,
  station_id STRING,
  ts TIMESTAMP,
  kwh DOUBLE
)
PARTITIONED BY SPEC (station_id)
STORED BY ICEBERG;

INSERT INTO ice_func VALUES
  (1, 'TS-101', '2026-01-15 08:00:00', 1.5),
  (2, 'TS-101', '2026-01-15 09:00:00', 2.0),
  (3, 'TS-204', '2026-01-15 08:00:00', 0.7),
  (4, 'TS-204', '2026-02-01 08:00:00', 0.9),
  (5, 'TS-305', '2026-02-01 08:00:00', 3.1);
```

## B1. Schema evolution

**Goal:** Change columns without rewriting a single data file. Iceberg tracks columns by **ID**, not by name or position, so renames and reorders are safe.

```sql
ALTER TABLE ice_func ADD COLUMNS (quality STRING);
ALTER TABLE ice_func CHANGE COLUMN kwh energy_kwh DOUBLE;        -- rename
ALTER TABLE ice_func CHANGE COLUMN id id BIGINT;                  -- widen INT -> BIGINT
SELECT * FROM ice_func ORDER BY id;
```

Old rows show `NULL` for `quality`; the renamed column still returns the old values. Check the data folder: no file was rewritten. Compare with a plain Parquet table, where a rename breaks the mapping of old files.

Allowed type changes are widening only (`INT` -> `BIGINT`, `FLOAT` -> `DOUBLE`, wider `DECIMAL` precision). Dropping a column is metadata-only too:

```sql
ALTER TABLE ice_func DROP COLUMN quality;
```

Time travel and schema: a query `FOR SYSTEM_VERSION AS OF` an old snapshot uses the schema **of that snapshot** in Impala and Hive, but the **current** schema in Spark's DataFrame reader — see C2.

## B2. Partition transforms and hidden partitioning

**Goal:** Partition by a function of a column, and let queries benefit without knowing the layout.

`ice_func` is partitioned by the identity of `station_id`. Create a second table partitioned by a **transform** of the timestamp:

```sql
CREATE TABLE ice_func_month (id BIGINT, station_id STRING, ts TIMESTAMP, energy_kwh DOUBLE)
PARTITIONED BY SPEC (MONTH(ts), BUCKET(4, station_id))
STORED BY ICEBERG;

INSERT INTO ice_func_month SELECT * FROM ice_func;

SELECT * FROM ${ws_user}.ice_func_month.partitions;
SHOW PARTITIONS ice_func_month;
SELECT * FROM ice_func_month WHERE ts >= '2026-02-01' AND ts < '2026-03-01';
```

| Transform | Meaning |
|-----------|---------|
| `IDENTITY` (plain column) | value as is |
| `YEAR`, `MONTH`, `DAY`, `HOUR` | on `DATE` / `TIMESTAMP` |
| `BUCKET(n, col)` | hash of the value modulo n — spreads high-cardinality keys |
| `TRUNCATE(w, col)` | first `w` characters of a string, or integer rounded down to a multiple of `w` |

The query filters on `ts`, not on a partition column: Iceberg maps the predicate to the partition values itself (**hidden partitioning**). There is no extra `month` column that every writer must fill correctly, and no `RECOVER PARTITIONS`. In the Hive-style layout (lab section 1) a wrong value in the partition column puts the row in the wrong folder; here that error class does not exist.

Look at the folders on HDFS: the names (`ts_month=2026-02`, `station_id_bucket=2`) are derived from the spec and are not meant for users to read or write.

## B3. Partition evolution

**Goal:** Change the partitioning of a live table. Old data keeps its layout, new data uses the new one.

```sql
ALTER TABLE ice_func_month SET PARTITION SPEC (DAY(ts));
INSERT INTO ice_func_month VALUES (6, 'TS-101', '2026-03-01 08:00:00', 1.1);

SELECT * FROM ${ws_user}.ice_func_month.partitions;
DESCRIBE FORMATTED ice_func_month;
```

The table now has **two partition specs**. Queries work across both; planning splits the predicate per spec. Nothing was rewritten — if you want old data in the new layout, compact (B7) or rewrite it explicitly. Hive-style tables can only be repartitioned by creating a new table and copying everything.

## B4. Metadata tables

**Goal:** Everything the engine knows about the table is queryable with SQL. Address a metadata table as `<db>.<table>.<name>` (Impala, Hive) or `<db>.<table>.<name>` / `<table>.<name>` (Spark).

| Metadata table | What it shows | Typical question |
|----------------|---------------|------------------|
| `snapshots` | one row per commit: id, time, operation, summary, manifest list | who changed the table when? |
| `history` | the timeline of the **current** pointer incl. `is_current_ancestor` | what was current at 09:00? was it rolled back? |
| `files` / `data_files` / `delete_files` | every file with `content`, row count, size, column bounds | why is the table slow? how many small files? |
| `manifests` | one row per manifest, with partition summaries | are manifests growing? (see rewrite manifests) |
| `partitions` | rows and files per partition (and spec) | skew? small partitions? |
| `refs` | branches and tags and the snapshot each points to | what is protected from expiry? |
| `metadata_log_entries` | the chain of `metadata.json` files | where is the commit history of the pointer? |
| `entries`, `all_files`, `all_manifests`, `all_entries` | across **all** snapshots, not only the current one | what would expiry delete? |

```sql
SELECT snapshot_id, committed_at, operation, summary FROM ${ws_user}.ice_func.snapshots;
SELECT content, file_path, record_count, file_size_in_bytes FROM ${ws_user}.ice_func.files;
SELECT * FROM ${ws_user}.ice_func.manifests;
SELECT * FROM ${ws_user}.ice_func.partitions;
SELECT * FROM ${ws_user}.ice_func.metadata_log_entries;
```

Which of these tables each engine exposes differs — see C3. A **small-file health query** works everywhere `files` does:

```sql
SELECT COUNT(*) AS files, ROUND(AVG(file_size_in_bytes) / 1024, 1) AS avg_kb,
       SUM(CASE WHEN content > 0 THEN 1 ELSE 0 END) AS delete_files
FROM ${ws_user}.ice_func.files;
```

## B5. Table properties that matter

```sql
SHOW TBLPROPERTIES ice_func;
ALTER TABLE ice_func SET TBLPROPERTIES (
  'write.parquet.compression-codec'='zstd',
  'write.target-file-size-bytes'='134217728',
  'history.expire.max-snapshot-age-ms'='604800000',
  'history.expire.min-snapshots-to-keep'='5',
  'write.metadata.delete-after-commit.enabled'='true',
  'write.metadata.previous-versions-max'='20'
);
```

| Property | Effect |
|----------|--------|
| `format-version` | `2` for row-level deletes; `3` (deletion vectors) from Runtime 7.3.2 SP1, Technical Preview |
| `write.format.default` | `parquet` (default); ORC and Avro are **read-only in Impala** |
| `write.parquet.compression-codec` | `snappy`/`zstd`/`gzip`/… — Impala and Spark honor it; check Hive **(verify)** |
| `write.target-file-size-bytes` | target size of data files (compaction goal) |
| `write.delete.mode`, `write.update.mode`, `write.merge.mode` | `merge-on-read` or `copy-on-write` per operation — honored by Hive and Spark, **ignored by Impala** (always merge-on-read) |
| `history.expire.max-snapshot-age-ms`, `history.expire.min-snapshots-to-keep` | defaults for `expire_snapshots` (Spark and Hive); Impala `EXPIRE_SNAPSHOTS` takes the timestamp you give it |
| `write.metadata.delete-after-commit.enabled`, `write.metadata.previous-versions-max` | clean up old `metadata.json` files |
| `external.table.purge` | whether `DROP TABLE` deletes the files |
| `gc.enabled` | `false` blocks destructive actions (expire, orphan removal) — handy for tables that other tables share files with |

## B6. Rollback, set current snapshot, cherry-pick

**Goal:** All "go back" operations are metadata-only; know the differences.

```sql
SELECT snapshot_id, committed_at, operation FROM ${ws_user}.ice_func.snapshots ORDER BY committed_at;

-- Impala (and Hive): a path back to a known good snapshot
ALTER TABLE ice_func EXECUTE ROLLBACK(<snapshot_id>);
-- or by time: everything after this moment is undone
ALTER TABLE ice_func EXECUTE ROLLBACK('2026-01-15 09:30:00');
```

| Operation | What it does | Engines |
|-----------|--------------|---------|
| `ROLLBACK` | makes an **ancestor** snapshot current again | Impala, Hive, Spark (`rollback_to_snapshot`, `rollback_to_timestamp`) |
| `SET_CURRENT_SNAPSHOT` | makes **any** snapshot current — also one that is not an ancestor (e.g. after an earlier rollback: "roll forward") | Hive `EXECUTE SET_CURRENT_SNAPSHOT(<id>)`, Spark `set_current_snapshot` **(verify Impala)** |
| `CHERRY_PICK` | applies the changes of one (staged or branch) snapshot to the current table | Hive `EXECUTE CHERRY_PICK(<id>)`, Spark `cherry_pick_snapshot` |
| `FAST_FORWARD` | moves one branch to the head of another | Hive `EXECUTE FAST_FORWARD('main', 'audit')`, Spark `fast_forward` |

Show `history` afterwards: `is_current_ancestor = false` for the undone snapshots, and a `set_current_snapshot` brings them back.

## B7. Maintenance: compaction, manifests, orphan files

**Goal:** Explain the four jobs a production Iceberg table needs. None of them run by themselves.

| Job | Why | Impala | Hive | Spark |
|-----|-----|--------|------|-------|
| Compact data and delete files | many small files, accumulated delete files slow readers | `OPTIMIZE TABLE t [(FILE_SIZE_THRESHOLD_MB=…)]` | `ALTER TABLE t COMPACT 'major'` **(verify)** | `CALL system.rewrite_data_files(...)` |
| Rewrite manifests | many small manifests slow planning | — **(verify)** | — | `CALL system.rewrite_manifests('db.t')` |
| Expire snapshots | free files of old snapshots | `ALTER TABLE t EXECUTE EXPIRE_SNAPSHOTS(<ts>)` | `ALTER TABLE t EXECUTE EXPIRE_SNAPSHOTS('<ts>')` | `CALL system.expire_snapshots(...)` |
| Remove orphan files | files left by failed jobs, which no metadata refers to | — | — | `CALL system.remove_orphan_files(...)` |

```sql
-- Impala
OPTIMIZE TABLE ice_func;
ALTER TABLE ice_func EXECUTE EXPIRE_SNAPSHOTS('2026-01-01 00:00:00');
```

Rules of thumb for the audience: compact **before** expiring (otherwise the files of the old layout stay until the next expiry); never run orphan removal with a retention shorter than the longest running write job (it would delete files of an uncommitted write); schedule all four (Oozie/Airflow/cron + Spark job), because unlike Hive ACID, Iceberg tables are not compacted by the Hive compactor on their own **(verify for 7.3.2 — a Hive-side automatic compaction of Iceberg tables is being added in recent releases)**.

## B8. Branches and tags

**Goal:** Name a snapshot (tag) or keep a second, writable line of history (branch). Typical use: tag the quarter-end state for audit; write-audit-publish on a staging branch.

Branches and tags live in the `refs` metadata table and are protected from expiry (until `max-ref-age-ms`). **Impala 7.3.2 does not create or write branches and tags (verify)**; it can read a tag/branch by snapshot ID, taken from `refs`.

```sql
-- Hive (Beeline)
ALTER TABLE ice_func CREATE TAG quarter_end FOR SYSTEM_VERSION AS OF <snapshot_id>;
ALTER TABLE ice_func CREATE BRANCH audit;
SELECT * FROM default.ice_func FOR SYSTEM_VERSION AS OF 'quarter_end';   -- (verify syntax in 7.3.2)
ALTER TABLE ice_func DROP TAG quarter_end;
```

```sql
-- Spark (needs the Iceberg SQL extensions, see C1)
ALTER TABLE ice_func CREATE TAG quarter_end AS OF VERSION <snapshot_id> RETAIN 365 DAYS;
ALTER TABLE ice_func CREATE BRANCH audit;
SELECT * FROM ice_func VERSION AS OF 'quarter_end';
INSERT INTO ice_func.branch_audit VALUES (99, 'TS-999', TIMESTAMP '2026-03-01 00:00:00', 0.0);
SELECT * FROM ice_func.branch_audit;
CALL system.fast_forward('ice_func', 'main', 'audit');   -- publish
```

Write-audit-publish: write to `branch_audit`, run data-quality checks there, then fast-forward `main` — readers of `main` never see unvalidated data.

## B9. Migrate existing tables

**Goal:** Turn the plain tables from lab section 0–1 into Iceberg tables.

| Approach | Command | Copies data? | Notes |
|----------|---------|--------------|-------|
| In place | Impala/Hive `ALTER TABLE t CONVERT TO ICEBERG;` | no | Parquet/ORC/Avro source; the original files become the first snapshot. No rollback to the old format |
| In place, with a copy of the metadata | Spark `CALL system.migrate('db.t')` | no | keeps a backup table `t_backup_` |
| Try first, don't touch the source | Spark `CALL system.snapshot('db.src', 'db.src_ice')` | no | new Iceberg table sharing the files. **Do not write to both** or expire on the snapshot table |
| Add files to an existing table | Spark `CALL system.add_files(table => 'db.ice', source_table => 'db.src')` | no | registers files, no rewrite |
| Copy | `CREATE TABLE ice STORED BY ICEBERG AS SELECT * FROM src` (Impala/Hive) | yes | the cleanest layout: new files, chosen partition spec |

```sql
-- Impala
CREATE TABLE meter_parquet STORED AS PARQUET AS SELECT * FROM grid_measurements_csv;
ALTER TABLE meter_parquet CONVERT TO ICEBERG;
```

## B10. Changes between snapshots (incremental read)

**Goal:** Process only what changed since the last run — the lakehouse answer to "which rows are new?".

```sql
-- Spark SQL
SELECT * FROM ice_func.snapshots;
CALL system.create_changelog_view(table => 'ice_func', options => map('start-snapshot-id','<s1>','end-snapshot-id','<s2>'));
```

```python
# PySpark: rows appended between two snapshots
(spark.read.format("iceberg")
    .option("start-snapshot-id", "<s1>")      # exclusive
    .option("end-snapshot-id", "<s2>")        # inclusive
    .load("ice_func").show())
```

The incremental **append** read returns only inserted rows (it ignores deletes and overwrites); the **changelog view** also shows updates and deletes. In Impala and Hive the equivalent is a join of two time-travel reads (lab section 6, "Join two snapshots").

---

# Part C — One table, three engines

Create the table in one engine, change it in the second, read it in the third. The point for the audience: **same files, same metadata, different defaults and different feature sets.**

## C1. Connect

**Impala:** Hue editor (as above) or `impala-shell` with the options from the handout.

**Hive:** Beeline with the JDBC URL from the handout (HiveServer2):

```bash
beeline -u "<hs2-jdbc-url-from-handout>"
```

**Spark:** `pyspark` (or `spark3-shell`) after `kinit`. In CDP the Iceberg runtime is part of the Spark 3 parcel; the Hive catalog is the session catalog. Features beyond reading and writing (stored procedures `CALL system.*`, `ALTER TABLE … ADD PARTITION FIELD`, branches and tags) need the **Iceberg SQL extensions**:

```bash
pyspark \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
  --conf spark.sql.catalog.spark_catalog.type=hive
```

(In many 7.3.x setups these are already in the cluster defaults — verify with `spark.conf.get("spark.sql.extensions")`.)

## C2. Create, write, and read the same table

```sql
-- Impala
CREATE TABLE ice_cmp (id INT, name STRING, amount DOUBLE)
STORED BY ICEBERG;
INSERT INTO ice_cmp VALUES (1, 'from-impala', 1.0);
```

```sql
-- Hive (Beeline)
INSERT INTO ice_cmp VALUES (2, 'from-hive', 2.0);
SELECT * FROM ice_cmp;
SELECT snapshot_id, committed_at, operation FROM default.ice_cmp.snapshots;   -- use your database
```

```python
# Spark
spark.sql("INSERT INTO ice_cmp VALUES (3, 'from-spark', 3.0)")
spark.table("ice_cmp").show()
spark.sql("SELECT snapshot_id, committed_at, operation FROM ice_cmp.snapshots").show()
```

Back in Impala: run `REFRESH ice_cmp;` (Impala caches table metadata, and changes made by other engines are not always picked up automatically **(verify)**), then show the `snapshots` table with three rows — three engines, one history.

**Create a table in each engine** — the DDL differs:

| | Impala | Hive | Spark |
|---|--------|------|-------|
| Format clause | `STORED BY ICEBERG` (`STORED AS ICEBERG` also works) | `STORED BY ICEBERG` | `USING iceberg` |
| Partitioning | `PARTITIONED BY SPEC (MONTH(ts), BUCKET(4, id))` | `PARTITIONED BY SPEC (month(ts), bucket(4, id))` | `PARTITIONED BY (months(ts), bucket(4, id))` |
| Table type | `CREATE TABLE` (no `EXTERNAL`) | `CREATE TABLE` (no `EXTERNAL`) | `CREATE TABLE` (external in the Metastore, files owned by Iceberg) |
| Format version | v2 is the default, nothing to set | same | same (`'format-version'='2'` is the default) |
| CTAS | yes | yes | yes (`CREATE TABLE … USING iceberg AS SELECT`) |
| Create from DataFrame | — | — | `df.writeTo("t").using("iceberg").partitionedBy(F.months("ts")).createOrReplace()` |

**Time travel syntax**:

| | Impala | Hive | Spark |
|---|--------|------|-------|
| By snapshot ID | `FOR SYSTEM_VERSION AS OF <id>` | `FOR SYSTEM_VERSION AS OF <id>` | `VERSION AS OF <id>` / `.option("snapshot-id", id)` |
| By time | `FOR SYSTEM_TIME AS OF '<ts>'` (UTC) | `FOR SYSTEM_TIME AS OF '<ts>'` (session time zone) | `TIMESTAMP AS OF '<ts>'` (session time zone) / `.option("as-of-timestamp", ms)` |
| Schema used | schema of the snapshot | schema of the snapshot | SQL: schema of the snapshot; DataFrame with `snapshot-id`/`as-of-timestamp` option: **current** schema |

Time-zone traps: Impala's `FOR SYSTEM_TIME AS OF` interprets the timestamp as UTC (Hive: the HiveServer2 session time zone; Spark: `spark.sql.session.timeZone`). On a UTC cluster all three agree; elsewhere the same literal can hit different snapshots.

## C3. Feature matrix on Runtime 7.3.2

Legend: **R/W** read and write, **R** read only, — not supported, **(v)** verify in your build.

| Feature | Impala | Hive | Spark |
|---------|--------|------|-------|
| Create / read / `INSERT` / `INSERT OVERWRITE` | R/W | R/W | R/W |
| `UPDATE`, `DELETE`, `MERGE` | yes (7.3.1.500+) | yes | yes (needs the SQL extensions for `MERGE`) |
| Row-level mode | **merge-on-read only** | merge-on-read or copy-on-write (`write.*.mode`) | copy-on-write (default of the property) or merge-on-read (`write.*.mode`) |
| Read position deletes | yes | yes | yes |
| Read equality deletes | (v) | yes | yes |
| Write file format | Parquet only (reads Parquet, ORC, Avro) | Parquet, ORC, Avro | Parquet, ORC, Avro |
| Partition transforms | identity, year/month/day/hour, bucket, truncate | same | same (`years`, `months`, `days`, `hours`, `bucket`, `truncate`) |
| Partition evolution | `ALTER TABLE … SET PARTITION SPEC` | `ALTER TABLE … SET PARTITION SPEC` | `ALTER TABLE … ADD / DROP / REPLACE PARTITION FIELD` (extensions) |
| Schema evolution | add / rename / drop / widen | add / rename / drop / widen | add / rename / drop / widen / reorder |
| Time travel | `FOR SYSTEM_TIME/VERSION AS OF` | same | `TIMESTAMP/VERSION AS OF` |
| Metadata tables | `snapshots`, `history`, `files`, `manifests`, `partitions`, `refs`, `metadata_log_entries`, … (v) | `snapshots`, `history`, `files`, `manifests`, `partitions`, `refs`, … (v) | all of the above, incl. `entries`, `all_*`, `position_deletes` |
| Rollback | `EXECUTE ROLLBACK(id \| ts)` | `EXECUTE ROLLBACK(id \| ts)` | `CALL system.rollback_to_snapshot / rollback_to_timestamp` |
| Expire snapshots | `EXECUTE EXPIRE_SNAPSHOTS(ts)` | `EXECUTE EXPIRE_SNAPSHOTS(ts)` | `CALL system.expire_snapshots` |
| Compaction | `OPTIMIZE TABLE` (v) | `ALTER TABLE … COMPACT` (v) | `CALL system.rewrite_data_files` |
| Rewrite manifests / orphan files | — (v) | — | `rewrite_manifests`, `remove_orphan_files` |
| Branches and tags | read only, via snapshot ID (v) | create / drop / read (v) | create / drop / read / write |
| Incremental read, changelog | — | — | yes |
| Migrate in place | `CONVERT TO ICEBERG` | `CONVERT TO ICEBERG` | `system.migrate`, `snapshot`, `add_files` |
| Sort order | — | — | `ALTER TABLE … WRITE ORDERED BY …` |
| Format version 3 (deletion vectors) | Technical Preview from 7.3.2 SP1 | same | same |

## C4. Row-level changes: the same statement, different files

Run the same `UPDATE` three times on three copies of the table and look at `files` after each. This is the clearest demonstration of "same logical result, different physical layout".

```sql
-- Impala:  merge-on-read, always
UPDATE ice_cmp SET amount = amount + 100 WHERE id = 1;
SELECT content, file_path, record_count FROM ${ws_user}.ice_cmp.files ORDER BY content;
```

```sql
-- Hive: set the mode, then compare both
ALTER TABLE ice_cmp SET TBLPROPERTIES ('write.update.mode'='copy-on-write');
UPDATE ice_cmp SET amount = amount + 100 WHERE id = 2;       -- rewrites the data file; no delete file
ALTER TABLE ice_cmp SET TBLPROPERTIES ('write.update.mode'='merge-on-read');
UPDATE ice_cmp SET amount = amount + 100 WHERE id = 2;       -- adds a delete file
SELECT content, file_path, record_count FROM default.ice_cmp.files;
```

```sql
-- Spark SQL: same properties
ALTER TABLE ice_cmp SET TBLPROPERTIES ('write.update.mode'='merge-on-read', 'write.merge.mode'='merge-on-read', 'write.delete.mode'='merge-on-read');
UPDATE ice_cmp SET amount = amount + 100 WHERE id = 3;
SELECT content, file_path, record_count FROM ice_cmp.files;
```

What to point out:

- **Copy-on-write**: the data file is rewritten, no delete files; slow write, fastest reads. Good for rarely updated tables read by many.
- **Merge-on-read**: tiny delete file, fast write; every reader pays the merge until compaction. Good for frequent small corrections (meter readings).
- Impala **ignores** the `write.*.mode` properties and always writes delete files. Impala can read tables written copy-on-write by the other engines without difficulty; the properties only affect writers.
- A table that is written by several engines needs one **agreed mode**, set as a table property, and **one scheduled compaction** that all engines can live with.

## C5. Maintenance from each engine

```sql
-- Spark: compaction with a size target, then expire, then orphans
CALL system.rewrite_data_files(table => 'ice_cmp', options => map('target-file-size-bytes','134217728','min-input-files','2'));
CALL system.rewrite_manifests('ice_cmp');
CALL system.expire_snapshots(table => 'ice_cmp', older_than => TIMESTAMP '2026-02-01 00:00:00', retain_last => 5);
CALL system.remove_orphan_files(table => 'ice_cmp', older_than => TIMESTAMP '2026-02-01 00:00:00', dry_run => true);
```

```sql
-- Impala
OPTIMIZE TABLE ice_cmp;
ALTER TABLE ice_cmp EXECUTE EXPIRE_SNAPSHOTS('2026-02-01 00:00:00');
```

```sql
-- Hive
ALTER TABLE ice_cmp EXECUTE EXPIRE_SNAPSHOTS('2026-02-01 00:00:00');
ALTER TABLE ice_cmp EXECUTE EXPIRE_SNAPSHOTS RETAIN LAST 5;    -- (verify syntax)
```

Differences to explain:

- Spark's `expire_snapshots` honors `retain_last` and the table properties (`history.expire.*`); Impala's and Hive's `EXPIRE_SNAPSHOTS` take a timestamp.
- Only Spark can **dry-run** orphan removal and tune the compaction (`target-file-size-bytes`, `min-input-files`, sort or z-order strategy). That is why many shops compact from Spark even if all queries are Impala.
- `OPTIMIZE TABLE` in Impala rewrites small data files **and applies delete files** (it needs `ALL` on the table in Ranger).

## C6. Behavior differences to know about

| Topic | Impala | Hive | Spark |
|-------|--------|------|-------|
| Metadata cache | Catalog server caches the table; `REFRESH` / `INVALIDATE METADATA` after a change from outside Impala if you see stale data | none, reads the pointer on each query | none, but a long-running session may cache table metadata until `REFRESH TABLE` |
| `DROP TABLE` | files removed if `external.table.purge`=true | purge by default for Iceberg (verify) | metadata only; `DROP TABLE … PURGE` also deletes the files |
| `TRUNCATE TABLE` | supported | supported | supported (creates an empty snapshot; files are removed by expiry) |
| `INSERT OVERWRITE` | partition-wise (dynamic) for partitioned tables | partition-wise (dynamic) | depends on `spark.sql.sources.partitionOverwriteMode`; prefer `INSERT OVERWRITE` with an explicit predicate or `MERGE` |
| Authorization | Ranger Hadoop SQL policies (+ storage handler policy for DDL) | same | storage level (HDFS/Ozone policy); Hadoop SQL policies only with the Spark/Ranger integration (verify) |
| Concurrency | optimistic; fails with a message after retries | optimistic; retries | optimistic; retries (`commit.retry.num-retries`) |
| Default timestamps | Iceberg `timestamp` is stored as UTC (no zone); `timestamptz` read as UTC | session time zone | `TIMESTAMP` vs `TIMESTAMP_NTZ` — check which type the column is |
| Where do you see the plan? | Impala query profile (`Hdfs Scan: Iceberg…`, delete files, partition pruning) | Tez/HiveServer2 explain | Spark UI SQL tab (`BatchScan`, pushed filters) |
| Typical role | interactive SQL, BI | ETL, ACID compatibility, admin operations | heavy ETL, maintenance, streaming, ML, incremental reads |

**Workshop message:** Pick the engine for the workload, not for the table. Impala for interactive queries and row-level corrections, Hive for SQL batch with Hive-specific features (branches, set-current-snapshot), Spark for maintenance, streaming ingestion, and incremental processing — all on **one Iceberg table** with one Ranger-protected folder.

### Exercise: three engines, one table

1. Impala: create `ice_cmp` (C2), insert one row.
2. Hive: insert one row, run `UPDATE` on the Impala row.
3. Spark: insert one row, `DELETE` the Hive row, then run `rewrite_data_files`.
4. Impala: `REFRESH ice_cmp;`, `SELECT * FROM ice_cmp;`, `SELECT snapshot_id, operation FROM ${ws_user}.ice_cmp.snapshots;` — what happened in what order? Which engine wrote delete files?

---

## Version checklist

Confirm on the target 7.3.2 cluster and move the results to the pitfalls table in [notes.md](notes.md):

1. Impala: `OPTIMIZE TABLE` options, `ALTER TABLE … EXECUTE ROLLBACK('<timestamp>')`, metadata tables `refs`, `metadata_log_entries`, `manifests`, `partitions`, `all_*`.
2. Impala: branch and tag support (read by name?) and equality-delete reading.
3. Hive: `COMPACT` for Iceberg, `EXECUTE SET_CURRENT_SNAPSHOT / CHERRY_PICK / FAST_FORWARD`, branch/tag read syntax, `EXPIRE_SNAPSHOTS RETAIN LAST`.
4. Hive: default of `write.*.mode` and of `external.table.purge` for Iceberg tables.
5. Spark: preconfigured extensions and catalog; `CALL system.*` available; branch/tag SQL; Ranger enforcement on Iceberg reads.
6. Time-zone behavior of time travel in all three engines.
7. Whether a Hive-side automatic compaction of Iceberg tables is active.

## Clean up

```sql
DROP TABLE IF EXISTS demo_ice;
DROP TABLE IF EXISTS ice_func;
DROP TABLE IF EXISTS ice_func_month;
DROP TABLE IF EXISTS ice_cmp;
```

```bash
hdfs dfs -ls "${HIVE_EXT}"     # remove leftover folders if external.table.purge was false
```

See [notes.md](notes.md) for where these fit in the ~120 minute session (A1 after lab section 5; Part B and C as a second session or a trainer-led extension).
