# Atlas UI hands-on lab

Run sections in order. You need **Hue** (Hive editor) and **Atlas** (URL from your handout, usually via Knox). All SQL runs in **Hue → Editor → Hive**.

Adjust `WORKSHOP_ROOT` in the SQL below if your cluster uses a different workshop path. The lab uses the placeholder `${ws_user}` — Hue shows an input field for it; type your short username (same as for `kinit`).

This lab builds its own database and tables from shared workshop CSV data on HDFS. Nothing from other modules is required.

**Pacing tip:** Run section 3 (CTAS) as soon as section 1 finishes. Atlas catches up in the background while you explore the UI in sections 2 and 4.

---

## 0. Orient — Atlas and the Hive hook
**Goal:** Know why tables appear in Atlas without you opening Atlas first.

When Hive creates or changes a table, the **Hive Atlas hook** publishes metadata events (via Kafka) into **Atlas**. Atlas stores **metadata and lineage**, not the table data in HDFS.

Open Atlas from your handout. Note the **Search** bar and the **Classifications** and **Glossary** areas in the navigation — you use them in sections 2, 5, and 6.

---

## 1. Create a source table

**Goal:** Create a small managed table Atlas can catalog.

In Hue, paste and run (set `${ws_user}` and replace the `LOCATION` path if your trainer gave another `WORKSHOP_ROOT`):

```sql
CREATE DATABASE IF NOT EXISTS ${ws_user};
USE ${ws_user};

CREATE EXTERNAL TABLE IF NOT EXISTS atlas_meter_ext (
  ts_utc STRING,
  station_id STRING,
  device_id STRING,
  active_power_kw DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/2026_cdp_workshop/08-atlas/data'
TBLPROPERTIES ('skip.header.line.count'='1');

CREATE TABLE atlas_meter_src AS
SELECT ts_utc, station_id, device_id, active_power_kw
FROM atlas_meter_ext
WHERE station_id IS NOT NULL
LIMIT 500;
```

Confirm in Hue:

```sql
SELECT COUNT(*) FROM atlas_meter_src;
DESCRIBE atlas_meter_src;
```

You should see a few hundred rows and four columns including `device_id`.

---

## 2. Find the table in Atlas

**Goal:** Search for a `hive_table` entity and read its metadata.

Atlas has three ways to search. Try the first two on your table; the third is a quick look (about one minute each):

| Search | Where | Use it for | Try this |
|--------|-------|------------|----------|
| **Search bar** (free text) | Top of the page | "I know a word, find it anywhere" — names, descriptions, owners, locations; ranked results; `*` is a wildcard | `atlas_meter*` |
| **Basic Search** | Left panel | Browse and filter: pick a type, classification, or term, then add attribute filters (`=`, `contains`, `begins_with`, dates) | Type `hive_table`, add filter `name` `begins_with` `atlas_meter` |
| **Advanced Search** | Left panel, switch from Basic | Exact, SQL-like queries: relationships, deleted entities, aggregates | `from hive_table where name like "atlas_meter*" select name, owner, createTime` |

Rule of thumb: bar to find, Basic to browse and filter, Advanced to ask precise questions (and the heaviest on the server). Open the entity for your database in the results.

Walk through:

- **Properties** — owner, create time, table type, HDFS location.
- **Schema** — column names and types match Hive.

If the entity is missing, wait up to one minute and refresh search. The hook is asynchronous.

![Atlas: search results for atlas_meter_src](img/atlas-01-search-result.png)

> **Screenshot fallback:** In Atlas, use **Search**, type `atlas_meter_src`, and open the hit with type **`hive_table`**. The qualified name should include your Hive database and table name. You should see at least one result before opening the detail page.

![Atlas: table detail — Properties and Schema](img/atlas-02-table-detail.png)

> **Screenshot fallback:** On the entity page, open **Properties** and confirm **owner**, **create time**, and a **location** under the warehouse. Open **Schema** and confirm `ts_utc`, `station_id`, `device_id`, and `active_power_kw`.

**Check question:** Does Atlas store the meter readings themselves, or only metadata about the table?

---

## 3. Create CTAS children

**Goal:** Add two downstream tables so lineage has something to draw.

Run in Hue (stay in `${ws_user}`):

```sql
CREATE TABLE atlas_meter_daily AS
SELECT
  station_id,
  substr(ts_utc, 1, 10) AS day,
  SUM(active_power_kw) AS sum_active_power_kw
FROM atlas_meter_src
GROUP BY station_id, substr(ts_utc, 1, 10);

CREATE TABLE atlas_meter_anonymized AS
SELECT ts_utc, station_id, active_power_kw
FROM atlas_meter_src;
```

Optional stretch (only if you have time): `CREATE TABLE atlas_meter_daily_v2 AS SELECT * FROM atlas_meter_daily WHERE sum_active_power_kw > 0;` — a second hop in lineage.

---

## 4. Lineage

**Goal:** Read downstream and upstream graphs and inspect the process that ran the CTAS.

In Atlas, open **`atlas_meter_src`** again. Select the **Lineage** tab.

- **Downstream:** you should see **`atlas_meter_daily`** and **`atlas_meter_anonymized`** linked through **process** nodes (the Hive queries).
- Click a **process** node and read the query text (CTAS statement).
- Open **`atlas_meter_anonymized`**. **Upstream** lineage should point back to **`atlas_meter_src`**.

Use the lineage controls (zoom, depth, show/hide process) if your Atlas version provides them.

**Exercise:** If `atlas_meter_src` had bad data, which of your two child tables would analysts still trust for “no device id” — and how do you see the dependency chain in Atlas?

![Atlas: downstream lineage from atlas_meter_src](img/atlas-03-lineage-downstream.png)

> **Screenshot fallback:** On **`atlas_meter_src`**, open **Lineage** and expand **downstream**. You should see two child **`hive_table`** entities and at least one **process** entity between parent and children. If children are missing, wait a minute after section 3 and refresh.

![Atlas: process node with CTAS query](img/atlas-04-lineage-process.png)

> **Screenshot fallback:** Click the **process** (often labeled with a Hive operation) between source and a child table. The detail panel should show SQL containing `CREATE TABLE` and `SELECT`.

If your cluster enables **column-level lineage**, expand lineage on a column such as `active_power_kw` — optional; table-level lineage is enough for this lab.

---

## 5. Classifications (tags) and propagation

**Goal:** Tag sensitive metadata and see the tag flow to derived tables.

In Atlas, open **Classifications** (or **Tag** management, depending on version). Create a classification named **`<your_username>_PII`** (the prefix avoids collisions on a shared Atlas).

Attach **`<your_username>_PII`** to **`atlas_meter_src`**, or attach it only to the **`device_id`** column if the UI allows column-level classifications.

Open **`atlas_meter_daily`** and **`atlas_meter_anonymized`**. Check **Classifications** on each child. With **propagation** enabled on the cluster, tags on the source often appear on downstream tables created through lineage.

Search Atlas for classification **`<your_username>_PII`** and confirm your tables appear in the results.

![Atlas: attach classification to table or column](img/atlas-05-tag-attach.png)

> **Screenshot fallback:** From the **`atlas_meter_src`** entity, use **Add Classification** (or **Classifications → Assign**). Pick or create **`<your_username>_PII`**. Save, then reopen the entity and confirm the tag is listed.

![Atlas: propagated tag on a CTAS child](img/atlas-06-tag-child.png)

> **Screenshot fallback:** Open **`atlas_meter_daily`** (or **`atlas_meter_anonymized`**). On **Classifications**, look for **`<your_username>_PII`** inherited from the source. If it is missing, your trainer may have propagation disabled — note that on the source entity only.

**Talking point:** **Ranger** can use these tags in **tag-based policies** (not exercised here). Tags describe sensitivity; Ranger enforces who may read or write.

---

## 6. Business glossary

**Goal:** Link a business term to a technical column.

The **business glossary** is a controlled vocabulary for the organization: **Glossary → Categories → Terms**. Terms have plain-language definitions and can be **assigned** to Atlas entities (tables and columns). Technical names (`active_power_kw`) and business names (“Active Power”) stay separate but searchable together.

Your trainer pre-created glossary **`Metering`** with term **`Active Power`**. If you must create it yourself (and you have permission): **Glossary → Create glossary** `Metering`, add category **`Consumption`**, add term **`Active Power`** with a short definition (for example: instantaneous active power at the meter, in kW).

Assign term **`Active Power`** to column **`active_power_kw`** on **`atlas_meter_src`** (or to the whole table if column assignment is awkward).

From the **term** side, open **`Active Power`** and confirm **`atlas_meter_src`** / **`active_power_kw`** appears under assigned entities. From the **table** side, confirm the term is linked.

![Atlas: glossary term Active Power](img/atlas-07-glossary-term.png)

> **Screenshot fallback:** Open **Glossary**, select **`Metering`**, open term **`Active Power`**. You should see definition text and tabs for related terms and assigned entities (empty until you assign).

![Atlas: term assigned to column active_power_kw](img/atlas-08-glossary-assignment.png)

> **Screenshot fallback:** On **`atlas_meter_src`**, use **Glossary Terms** (or **Assign term**) and link **`Active Power`**. Reopen the term **`Active Power`** and verify the table or column is listed.

---

## Wrap-up

**Final check question:** If `atlas_meter_src` is wrong, which downstream tables are affected, and which Atlas feature shows you the answer?

Optional cleanup in Hue (does not remove lineage history immediately):

```sql
DROP TABLE IF EXISTS atlas_meter_daily;
DROP TABLE IF EXISTS atlas_meter_anonymized;
DROP TABLE IF EXISTS atlas_meter_src;
DROP TABLE IF EXISTS atlas_meter_ext;
```

In Atlas, dropped tables often move to **DELETED** state but lineage remains visible — useful for audit discussions.

Run `./08-basics-atlas/lab/check.sh` from the repo on the edge node when you are done.

---

## Screenshot checklist (trainer)

Capture these under `lab/img/` when preparing materials:

1. `atlas-01-search-result.png` — search hit for `atlas_meter_src`
2. `atlas-02-table-detail.png` — Properties / Schema
3. `atlas-03-lineage-downstream.png` — source with two children
4. `atlas-04-lineage-process.png` — process node SQL
5. `atlas-05-tag-attach.png` — assign `<your_username>_PII`
6. `atlas-06-tag-child.png` — tag on a child table
7. `atlas-07-glossary-term.png` — term **Active Power**
8. `atlas-08-glossary-assignment.png` — term linked to column or table
