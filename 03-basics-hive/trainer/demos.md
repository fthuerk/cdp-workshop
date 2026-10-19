# Trainer live demos — Hive

Run **one section at a time** on an edge node while participants watch. Participant tables live in `ws_<user>` databases with data under `/warehouse/tablespace/external/hive/ws_<user>.db/<table>`.

```bash
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust from config.env
export HIVE_LAB="${WORKSHOP_ROOT}/03-hive"
```

Setup must be done before the session: [setup/setup.sh](../setup/setup.sh). Use your **own** demo user (for example `demo_trainer`) for Beeline demos so participants' tables stay untouched; use the admin ticket (`source lib/admin_auth.sh`) only for the HDFS views of managed tables.

---

## 1. Managed table files — what an UPDATE writes

**Goal:** Show the `base_` / `delta_` / `delete_delta_` folders that participants could not read in [lab section 8](../lab/lab.md).

As the demo user, create the table and change rows, then find the location:

```sql
CREATE TABLE demo_managed AS SELECT * FROM landisgyr_csv;
UPDATE demo_managed SET quality_flag = 'REVIEWED' WHERE quality_flag = 'WARN';
DELETE FROM demo_managed WHERE station_id = 'TS-305' AND event_code = 'HIGH_LOAD';
DESCRIBE FORMATTED demo_managed;
```

Switch to the admin ticket and list the location from the `DESCRIBE` output:

```bash
cd "${WORKSHOP_LOCAL}"    # repo path on the edge node
source lib/admin_auth.sh
hdfs dfs -ls -R "<managed-table-location>"
```

Point at the folder names: one `base_…` (from the CTAS), then `delta_…` for the update and `delete_delta_…` for the delete. Look inside one ORC file — ACID files carry hidden columns (operation, transaction ids) around your row:

```bash
hive --orcfiledump -d "<delta-or-delete-delta-file>" | head -5
```

Run a major compaction, wait, and list the location again:

```sql
ALTER TABLE demo_managed COMPACT 'major';
SHOW COMPACTIONS;
```

**Talking point:** Immutable files plus deltas — and why nobody edits managed table folders by hand.

---

## 2. DROP — external vs managed, side by side

**Goal:** Show the difference in files, not only in words.

Use `demo_managed` from section 1 and a new external table with a CSV copy in its folder. With the admin ticket, list both locations first:

```sql
CREATE EXTERNAL TABLE demo_ext LIKE landisgyr_csv;
DESCRIBE FORMATTED demo_ext;
```

```bash
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "<demo_ext-table-location>"
hdfs dfs -ls "<demo_ext-table-location>"
hdfs dfs -ls "<managed-table-location>"
```

Drop both tables as the demo user, then list both locations again:

```sql
DROP TABLE demo_ext;
DROP TABLE demo_managed;
```

The external table folder and its CSV are unchanged; the managed table folder is gone (or in trash, depending on trash settings).

**Optional:** `external.table.purge`. Set it on a throw-away external table and drop it:

```sql
ALTER TABLE demo_ext SET TBLPROPERTIES ('external.table.purge'='true');
DROP TABLE demo_ext;
```

Check on your cluster that the data is deleted — behavior for **partitions** (`DROP PARTITION`) differs between versions, so do not promise it without testing.

---

## 3. Small files and what fixes them

**Goal:** Make the cost of repeated `INSERT INTO` visible.

As the demo user, append a few rows ten times to an ORC external table and list the folder:

```sql
INSERT INTO meter_orc SELECT * FROM meter_csv LIMIT 10;
```

Repeat the statement several times, then:

```bash
hdfs dfs -ls "/warehouse/tablespace/external/hive/ws_<demo_user>.db/meter_orc"
```

Every run added a file. Fix with a rewrite (`INSERT OVERWRITE … SELECT * FROM meter_csv`) or, for ORC, merge the files of the table:

```sql
ALTER TABLE meter_orc CONCATENATE;
```

**Talking point:** Many small files hurt NameNode memory and Tez task counts. Managed tables compact automatically; external tables need a rewrite or `CONCATENATE`.

---

## 4. Column pruning — fewer bytes read

**Goal:** Show that columnar formats read only the columns a query needs.

Run the same single-column query on both tables and open the finished queries in the **Tez UI** (or the Hue Job Browser → query → counters):

```sql
SELECT AVG(active_power_kw) FROM meter_csv;
SELECT AVG(active_power_kw) FROM meter_orc;
```

Compare `HDFS_BYTES_READ` per query: the text file is read completely, the ORC file only for the stripe footer and the one column's streams.

**Talking point:** ORC/Parquet speed up analytics because queries rarely need all columns; CSV can never skip columns.

---

## 5. Ranger audit — a denied statement

**Goal:** Show that Hive access is governed by policy, not by file permissions alone.

As a participant account, try to read another participant's database (for example `SELECT * FROM ws_<other_user>.landisgyr_csv LIMIT 1;`). If your Ranger policies allow it, skip this section. Otherwise the statement fails; open **Ranger → Audit** and find the denied request.

**Talking point:** Hive column and row policies (masking) arrive in the governance module.

---

## Timing hint

See [notes.md](notes.md) for where these fit in the ~120 minute session (section 1 after lab section 8; the rest as time allows).
