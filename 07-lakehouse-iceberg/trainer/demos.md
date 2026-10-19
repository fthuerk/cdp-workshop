# Trainer demos — Module 07 Lakehouse (Iceberg)

Run **one section at a time** while participants watch. Each demo uses a throw-away table `demo_ice` in your own `ws_<trainer_user>` database. The setup for all demos:

```sql
CREATE EXTERNAL TABLE demo_ice (id INT, name STRING, amount DOUBLE)
STORED BY ICEBERG
STORED AS PARQUET
TBLPROPERTIES ('format-version'='2', 'write.format.default'='parquet', 'write.delete.format.default'='parquet');

INSERT INTO demo_ice VALUES (1, 'alpha', 10.0), (2, 'beta', 20.0), (3, 'gamma', 30.0);
```

## 1. Snapshot isolation — a long reader and a concurrent writer

**Goal:** Show that a running query keeps reading its snapshot while the table changes (lab section 7).

Make the reader slow so that you can change the table while it runs. The statement below adds a `sleep` per row through `reflect`; if your cluster blocks `reflect`, use a bigger table instead (insert the rows of `demo_ice` into itself several times). In **terminal A** start the slow query on `demo_ice`:

```sql
SELECT id, name, amount, reflect('java.lang.Thread', 'sleep', 20000L) FROM demo_ice;
```

In **terminal B** change the table while the query still runs:

```sql
UPDATE demo_ice SET amount = amount * 2;
SELECT * FROM demo_ice;
```

Terminal B shows the doubled amounts immediately; terminal A finishes with the **old** amounts. Run the query in terminal A again: now the new values. Point out that no one waited for anyone.

## 2. Two writers — optimistic concurrency

**Goal:** Show what happens when two commits meet (lab section 7, concurrent writers).

In terminal A and B (two Beeline sessions), start a slow `UPDATE` in both at about the same time, on the **same** rows:

```sql
UPDATE demo_ice SET name = concat(name, '-A') WHERE id = 1;
```

```sql
UPDATE demo_ice SET name = concat(name, '-B') WHERE id = 1;
```

Depending on timing and engine settings, one statement succeeds and the other either retries (and succeeds with the updated state) or fails with a message that the table changed while the statement ran. Show both outcomes if you can, and `SELECT * FROM demo_ice;` — no lost update. Contrast: with `INSERT OVERWRITE` on an external table, the last writer silently wins.

## 3. Files before and after compaction

**Goal:** Show why many small commits need maintenance.

Insert ten single rows, one statement each, and list the table folder:

```sql
INSERT INTO demo_ice VALUES (10, 'x', 1.0);
INSERT INTO demo_ice VALUES (11, 'x', 1.0);
INSERT INTO demo_ice VALUES (12, 'x', 1.0);
```

```bash
hdfs dfs -ls -R "/warehouse/tablespace/external/hive/ws_${WORKSHOP_USER}.db/demo_ice/data"
```

Every statement added a Parquet file (and a metadata file and a snapshot). Compact in Spark and list again:

```scala
spark.sql("CALL spark_catalog.system.rewrite_data_files('ws_<trainer_user>.demo_ice')")
```

Expire the old snapshots afterwards (`ALTER TABLE demo_ice EXECUTE EXPIRE_SNAPSHOTS(CURRENT_TIMESTAMP)`) and show that the small files are gone. Point out that this is scheduled maintenance in production.

## 4. Same table, a Ranger audit

**Goal:** Show that Iceberg tables are governed by the same Ranger policies as any other Hive table.

As a participant account without access to your `ws_<trainer_user>` database, run `SELECT * FROM ws_<trainer_user>.demo_ice;` in Hive and in Impala. Open **Ranger → Audit** and find both denied requests. If Spark reads the files directly, it is governed by the HDFS policy: show the HDFS audit entry too.

## 5. Drop

**Goal:** Contrast with plain external tables, where `DROP TABLE` keeps the files.

```sql
SHOW TBLPROPERTIES demo_ice;
DROP TABLE demo_ice;
```

```bash
hdfs dfs -ls "/warehouse/tablespace/external/hive/ws_${WORKSHOP_USER}.db/demo_ice"
```

Check whether the table folder is still there (depends on `external.table.purge`) and remove it if needed.

---

See [notes.md](notes.md) for where these fit in the ~150 minute session (demo 1 after lab section 7; the rest as time allows).
