# Ranger hands-on lab (Hive)

Run sections in order. You need **Hue** (Hive editor) and **Ranger** (both open from the Knox home page). All SQL runs in **Hue → Editor → Hive**.

The lab SQL uses the placeholder `${ws_user}` — Hue shows an input field for it; type your short username (same as for `kinit`).

Your trainer prepares shared tables in database **`ranger_lab`** before the session. You do **not** create Ranger policies in this document — the trainer changes policies live while you re-run queries and observe the effect.

**Pacing tip:** After each trainer announcement (“policy updated”), wait about **30 seconds**, then re-run the query from that section.

---

## 0. Orient — Ranger and Hive

**Goal:** Know what Ranger controls and what you will see in this lab.

**Ranger** enforces **authorization** (who may read or write which Hive resources) and records **audit** events. **Atlas** describes metadata and sensitivity; **Ranger** decides whether your query is allowed and can **mask** columns or **filter rows** in the result.

Policy types you touch today:

| Type | Effect on your query |
|------|----------------------|
| **Access** (allow / deny) | Query succeeds or fails with a permission error |
| **Column masking** | `SELECT` still runs; sensitive columns show masked values |
| **Row-level filter** | `SELECT` returns only rows that match a filter expression |

Evaluation order (simplified): **deny** policies beat **allow** policies for the same resource unless an exception applies.

HiveServer2 loads Ranger policy changes on a short interval (often about **30 seconds**). If results look “stuck,” wait and run again.

Open **Ranger** from Knox and locate **Audit → Access** — you use it in section 6.

---

## 1. Baseline — no access yet

**Goal:** See authorization fail before any allow policy exists.

In Hue, run:

```sql
SELECT * FROM ranger_lab.meter_readings LIMIT 5;
```

You should get a **permission denied** (or similar) error — not an empty table.

**Check question:** Did **Hive** (via Ranger) reject the query, or did HDFS block you directly? (Hint: you never reached table data.)

Optional — confirm the database exists but you cannot read the table:

```sql
SHOW TABLES IN ranger_lab;
```

Some clusters hide table names until you have metadata access; your trainer may adjust timing. The important outcome is: **`SELECT` on `meter_readings` fails** until section 2.

---

## 2. Allow — read the full table

**Goal:** After the trainer grants `SELECT`, read all columns in clear text.

When your trainer says the **allow** policy is active, wait ~30 seconds and run:

```sql
SELECT ts_utc, station_id, device_id, customer_name, customer_email, active_power_kw
FROM ranger_lab.meter_readings
ORDER BY ts_utc, station_id
LIMIT 10;
```

You should see multiple **station_id** values (for example `TS-101`, `TS-102`, `TS-305`, `TS-401`) and readable **customer_name** / **customer_email** values.

Count all rows (trainer data has **30** rows):

```sql
SELECT COUNT(*) AS total_rows FROM ranger_lab.meter_readings;
```

---

## 3. Column masking

**Goal:** Same query shape, different column values — masking applies at read time.

When your trainer enables **masking** policies, re-run:

```sql
SELECT device_id, customer_name, customer_email
FROM ranger_lab.meter_readings
LIMIT 5;
```

Compare with section 2:

- **device_id** — typically a **hash** (same input → same hash; not the original id)
- **customer_email** — **partially masked** (not full clear text)
- **customer_name** — often **NULL** or empty (nullify mask)

Test that filtering on clear text no longer works as before:

```sql
SELECT COUNT(*)
FROM ranger_lab.meter_readings
WHERE customer_email = 'alex.meter@example.com';
```

With masking active, this count is often **0** even though those rows exist — the predicate is evaluated against **masked** values.

**Check question:** If you `CREATE TABLE ... AS SELECT` into your personal database, do you copy real emails or masked values? (Try in section 7 if you have time.)

---

## 4. Row-level filter

**Goal:** Each participant sees only stations assigned to their user name.

When your trainer enables the **row-level filter**, run:

```sql
SELECT station_id, COUNT(*) AS rows_seen
FROM ranger_lab.meter_readings
GROUP BY station_id
ORDER BY station_id;
```

You should see **only one or two** stations — not all four. Compare with a neighbour: their station list should differ.

See your assignment (this table is also protected by allow policies):

```sql
SELECT station_id
FROM ranger_lab.station_assignment
WHERE user_name = '${ws_user}'
ORDER BY station_id;
```

The stations in this result should match the groups in the query above.

Total row count **after** the filter:

```sql
SELECT COUNT(*) FROM ranger_lab.meter_readings;
```

**Check question:** Does this `COUNT(*)` reflect **all** rows in the table, or only the rows **you** are allowed to see?

---

## 5. Deny overrides allow

**Goal:** Experience an explicit **deny** on a resource that was previously allowed.

When your trainer first **allows** `SELECT` on `customer_master`, run:

```sql
SELECT * FROM ranger_lab.customer_master;
```

You should see five rows (device ids and **iban_last4**).

When your trainer adds a **deny** policy for the workshop group, wait ~30 seconds and run the same query again.

You should get **permission denied** (deny wins over allow for your user).

**Check question:** If both an allow and a deny policy match your user on the same table, which result do you expect?

---

## 6. Audit

**Goal:** Find your Hive requests in Ranger audit logs.

In **Ranger → Audit → Access**, filter (fields vary slightly by version):

- **User** — your `${ws_user}` (or full principal if your cluster stores it that way)
- **Resource** — `ranger_lab` / `meter_readings` or `customer_master`
- **Result** — try **Denied** and **Allowed**

Open a few events from sections 1–5. Note **policy id**, **access type**, and **result**. Masked selects usually still appear as **allowed** access with masking applied server-side.

**Exercise:** Find one **denied** event from section 1 or 5 and one **allowed** event from section 2.

---

## 7. Wrap-up — writes and CTAS

**Goal:** Relate read policies to write attempts and masked exports.

Try to insert into the shared lab table (should fail):

```sql
INSERT INTO ranger_lab.meter_readings
VALUES ('2024-01-05 00:00:00', 'TS-101', 'DEV-9999', 'Test', 'test@example.com', 'North', 1.0);
```

Optional stretch — copy masked data into **your** database (personal database name = your user name):

```sql
CREATE DATABASE IF NOT EXISTS ${ws_user};
USE ${ws_user};

DROP TABLE IF EXISTS ranger_export_masked;
CREATE TABLE ranger_export_masked AS
SELECT device_id, customer_email, active_power_kw
FROM ranger_lab.meter_readings;
```

Inspect what you stored:

```sql
SELECT * FROM ranger_export_masked LIMIT 5;
```

**Final check question:** Name the four Ranger mechanisms you saw today (allow, deny, masking, row filter) and one place each showed up in Hue or Ranger Audit.

Run `./I2-basics-ranger/lab/check.sh` from the repo on the edge node **after** the trainer has applied the **final** policies (allow + masking + row filter). It does not verify Ranger UI steps.

---
