# Trainer demos — Module 07 Lakehouse (Iceberg)

Run **one section at a time** while participants watch. Each demo uses a throw-away table `demo_ice` in your own `<trainer_user>` database. Use two Hue Impala editor tabs (**A** and **B**) and one terminal for `hdfs`. The setup for all demos:

```sql
CREATE EXTERNAL TABLE demo_ice (id INT, name STRING, amount DOUBLE)
STORED AS ICEBERG
TBLPROPERTIES ('format-version'='2');

INSERT INTO demo_ice VALUES (1, 'alpha', 10.0), (2, 'beta', 20.0), (3, 'gamma', 30.0);
```

## 1. Snapshot isolation — a long reader and a concurrent writer

**Goal:** Show that a running query keeps reading its snapshot while the table changes (lab section 5).

Make the reader slow so that you can change the table while it runs. The statement below adds a `sleep` per row; if it finishes too fast, insert the rows of `demo_ice` into itself several times first. In **tab A** start the slow query on `demo_ice`:

```sql
SELECT id, name, amount, sleep(20000) FROM demo_ice;
```

In **tab B** change the table while the query still runs:

```sql
UPDATE demo_ice SET amount = amount * 2;
SELECT * FROM demo_ice;
```

Tab B shows the doubled amounts immediately; tab A finishes with the **old** amounts. Run the query in tab A again: now the new values. Point out that no one waited for anyone.

## 2. Two writers — optimistic concurrency

**Goal:** Show what happens when two commits meet.

In tab A and B, start an `UPDATE` in both at about the same time, on the **same** rows (start the second one right after the first, or add `sleep` to the filter to widen the window):

```sql
UPDATE demo_ice SET name = concat(name, '-A') WHERE id = 1;
```

```sql
UPDATE demo_ice SET name = concat(name, '-B') WHERE id = 1;
```

Depending on timing, one statement succeeds and the other either retries (and succeeds with the updated state) or fails with a message that the table changed while the statement ran. Show both outcomes if you can, and `SELECT * FROM demo_ice;` — no lost update. Contrast: with `INSERT OVERWRITE` on an external table, the last writer silently wins.

## 3. Files before and after compaction

**Goal:** Show why many small commits need maintenance.

Insert single rows, one statement each, and list the table folder:

```sql
INSERT INTO demo_ice VALUES (10, 'x', 1.0);
INSERT INTO demo_ice VALUES (11, 'x', 1.0);
INSERT INTO demo_ice VALUES (12, 'x', 1.0);
```

```bash
hdfs dfs -ls -R "/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db/demo_ice/data"
```

Every statement added a Parquet file (and a metadata file and a snapshot). Compact and list again:

```sql
OPTIMIZE TABLE demo_ice;
```

Expire the old snapshots afterwards (`ALTER TABLE demo_ice EXECUTE EXPIRE_SNAPSHOTS(now());`) and show that the small files are gone. Point out that this is scheduled maintenance in production. If your release has no `OPTIMIZE TABLE`, show the file count and the expiry only.

## 4. Same table, a Ranger audit

**Goal:** Show that Iceberg tables are governed by the same Ranger policies as any other table.

As a participant account without access to your `<trainer_user>` database, run `SELECT * FROM <trainer_user>.demo_ice;` in Hue (Impala). Open **Ranger → Audit** and find the denied request. A direct read of the files on HDFS is governed by the HDFS policy: show the HDFS audit entry too.

## 5. Drop

**Goal:** Contrast with plain external tables, where `DROP TABLE` keeps the files.

```sql
SHOW TBLPROPERTIES demo_ice;
DROP TABLE demo_ice;
```

```bash
hdfs dfs -ls "/warehouse/tablespace/external/hive/${WORKSHOP_USER}.db/demo_ice"
```

Check whether the table folder is still there (depends on `external.table.purge`) and remove it if needed.

---

See [notes.md](notes.md) for where these fit in the ~120 minute session (demo 1 after lab section 5; the rest as time allows).
