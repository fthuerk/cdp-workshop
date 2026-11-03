# Setup — Module I1 Ranger (Hive)

Admin/trainer reference for preparing data, row-filter assignments and every Ranger policy the lab needs. It is ordered to match [`lab_basics_ranger.md`](../lab/lab_basics_ranger.md), sections 0–7. Click-by-click policy creation and timing are in [`../trainer/notes.md`](../trainer/notes.md).

Run SQL as an admin/DDL-capable user (e.g. `hive`), never as a `workshop` participant: Hive admins bypass masking and row filters, so test policies with a normal participant account.

## Lab section → what you must have ready

| Lab section | What participants do | Policy / data you provide | Expected outcome |
|-------------|----------------------|---------------------------|------------------|
| 0 Orient | read, find Ranger Audit | Ranger UI reachable via Knox | — |
| 1 Baseline | `SELECT` on `meter_readings` | **No** allow policy on `cdp_workshop` (start state) | permission denied |
| 2 Allow | full `SELECT`, `COUNT(*)` | **P1** allow (`select`) | 30 rows, clear PII, stations `TS-101/102/305/401` |
| 3 Masking | same query + `WHERE customer_email = 'alex.meter@example.com'` | **P2** three masking policies | hashed `device_id`, partial email, NULL name, count 0 |
| 4 Row filter | `GROUP BY station_id`, own assignment, `COUNT(*)` | **P3** row filter + `station_assignment` filled (section 2 below) | exactly 2 stations, matches own assignment, count below 30 |
| 5 Deny | `SELECT * FROM customer_master` twice | **P4** allow, then deny | 5 rows, then permission denied |
| 6 Audit | Ranger → Audit → Access | Ranger audit enabled (Solr/audit store) | denied + allowed events visible |
| 7 Wrap-up | `INSERT` into `meter_readings`; CTAS into `${ws_user}` | **No** insert/update on `cdp_workshop`; participants may create their own database | INSERT fails; CTAS stores masked values |

The end-of-lab `lab/check.sh` expects **P1 + P2 + P3** to be active: SELECT works, `customer_name` fully masked (NULL), 1–2 distinct stations, and the visible row count equals the count derived from `station_assignment` for the user.

---

## 1. Data (lab sections 1–5, 7)

Run [`setup.hql`](setup.hql). It is re-runnable (`CREATE TABLE IF NOT EXISTS`, then `TRUNCATE` and reload), so tables keep their Atlas tags. `meter_readings` is shared with I2-basics-atlas, whose `setup.hql` contains the same definition. It creates database `cdp_workshop` with:

| Table | Rows | Used in section |
|-------|------|-----------------|
| `meter_readings` | 30 (TS-101: 8, TS-102: 8, TS-305: 8, TS-401: 6) | 1, 2, 3, 4, 7 |
| `customer_master` | 5 | 5 |
| `station_assignment` | 2 per participant | 4 |

`setup.hql` inserts placeholder users `participant01..20`; replace them with the real users as described in section 2. (The repo currently provides `setup.hql`, `verify.hql`, `teardown.hql` only; the `.sh` wrappers mentioned in the README are not part of this folder.)

---

## 2. Generate `station_assignment` from the real user names (lab section 4)

When user names have no common pattern, generate the assignments from the list of actual names.

**Approach:** sort the users alphabetically, number them, take the rank modulo 4. This yields buckets that are as equal in size as possible (e.g. 5/5/5/5 for 20 users). A hash of the name gives uneven buckets for small groups; letter ranges are worse.

Each bucket `b` gets two neighbouring stations, `s[b]` and `s[(b+1) % 4]`, with `s = [TS-101, TS-102, TS-305, TS-401]`. This matches the lab text ("only one or two stations — not all four") and `check.sh` (1–2 distinct stations).

| Bucket | Stations | Rows visible to the user (`COUNT(*)` in lab section 4) |
|--------|----------|--------------------------------------------------------|
| 0 | `TS-101`, `TS-102` | 16 |
| 1 | `TS-102`, `TS-305` | 16 |
| 2 | `TS-305`, `TS-401` | 14 |
| 3 | `TS-401`, `TS-101` | 14 |

(`TS-401` has only 6 rows, hence 14 instead of 16.)

### 2.1 Get the user names

The names must equal what `current_user()` returns in Hive, i.e. the short name that participants type as `${ws_user}` (no realm).

```bash
# from HDFS home directories (adjust the filter to your naming)
hdfs dfs -ls /user | awk -F/ 'NR>1 {print $NF}' | grep '^<prefix>'

# or from the workshop group
getent group workshop

# or from FreeIPA
ipa group-show workshop
```

### 2.2 Load the names and generate the assignments

```sql
DROP TABLE IF EXISTS cdp_workshop.workshop_users;
CREATE TABLE cdp_workshop.workshop_users (user_name STRING);

-- paste the real short user names
INSERT INTO cdp_workshop.workshop_users VALUES
  ('user_a'), ('user_b'), ('user_c');   -- ...

TRUNCATE TABLE cdp_workshop.station_assignment;   -- removes the placeholder rows from setup.hql

INSERT INTO cdp_workshop.station_assignment
SELECT u.user_name,
       array('TS-101','TS-102','TS-305','TS-401')[(u.b + k.off) % 4]
FROM (
  SELECT user_name,
         (row_number() OVER (ORDER BY user_name) - 1) % 4 AS b
  FROM cdp_workshop.workshop_users
) u
CROSS JOIN (SELECT 0 AS off UNION ALL SELECT 1) k;
```

`workshop_users` is only a helper; it needs no Ranger access for participants (do not include it in the P1 table list). Re-run this section whenever the participant list changes.

### 2.3 Check the result

```sql
-- every user has exactly 2 stations: expect 0 rows
SELECT user_name, COUNT(*) AS n_stations
FROM cdp_workshop.station_assignment
GROUP BY user_name
HAVING COUNT(*) <> 2;

-- buckets balanced: each station appears about 2 * users / 4 times
SELECT station_id, COUNT(*) AS n_users
FROM cdp_workshop.station_assignment
GROUP BY station_id
ORDER BY station_id;
```

[`verify.hql`](verify.hql) additionally checks the table row counts.

### 2.4 Hash-in-filter alternative (not compatible with the lab as written)

```sql
station_id IN (
  array('TS-101','TS-102','TS-305','TS-401')[pmod(hash(current_user()), 4)],
  array('TS-101','TS-102','TS-305','TS-401')[pmod(hash(current_user()) + 1, 4)]
)
```

This needs no table but breaks three things: the lab section 4 query on `station_assignment`, `lab/check.sh` (which reads `station_assignment`), and the bucket sizes become uneven. Use it only if you also edit those; otherwise stay with 2.2.

---

## 3. Ranger policies (created live, in lab order)

Hive service in Ranger: usually `cm_hive` (adjust to your cluster). Access policies: **Access Manager → Hive → `<service>`**; masking: tab **Masking**; filters: tab **Row Level Filter**. All participants must be in group **`workshop`** (or `WORKSHOP_GROUP`).

**Start state (lab section 1):** no workshop policies on `cdp_workshop`, or all disabled. Default cluster policies must not grant participants `SELECT` on `cdp_workshop`.

After every change announce "policy updated" and have participants wait about 30 s (HiveServer2 policy refresh).

### 3.1 P1 — allow read (lab section 2)

| Policy | Resource | Group | Permissions |
|--------|----------|-------|-------------|
| `cdp_workshop_db_use` | db `cdp_workshop`, table `*`, column `*` | `workshop` | `select`, `read`, `refresh` (`use` if shown) |
| `cdp_workshop_read` | db `cdp_workshop`, tables `meter_readings`, `station_assignment`, `customer_master`, column `*` | `workshop` | `select` |

- `station_assignment` must be included: lab section 4 queries it, and the row filter subquery needs it.
- `customer_master` is included here so lab section 5 step 1 works; alternatively enable it separately as P4 step 1, right before section 5.
- Grant **only** `select`: lab section 7 expects the `INSERT` into `meter_readings` to fail.

### 3.2 P2 — column masking (lab section 3)

Tab **Masking**. Common to all three: db `cdp_workshop`, table `meter_readings`, Select Group `workshop`, permission `select`.

| Policy name | Column | Mask type | Participants see |
|-------------|--------|-----------|------------------|
| `cdp_workshop_mask_email` | `customer_email` | Partial mask (show last 4) or Email mask | local part hidden, domain visible |
| `cdp_workshop_mask_device` | `device_id` | Hash (SHA256 if offered) | stable hash instead of `DEV-0001` |
| `cdp_workshop_mask_name` | `customer_name` | Nullify | `NULL` |

- `cdp_workshop_mask_name` is required by `check.sh` (it asserts `customer_name` is fully masked), so do not drop it when cutting for time; drop `device_id` first.
- `WHERE customer_email = 'alex.meter@example.com'` is evaluated on masked values and returns 0 (lab section 3).
- Masked values are what CTAS copies in lab section 7.
- Keep P1 enabled.

### 3.3 P3 — row-level filter (lab section 4)

Tab **Row Level Filter**.

| Field | Value |
|-------|-------|
| Policy Name | `cdp_workshop_rows` |
| Database / Table | `cdp_workshop` / `meter_readings` |
| Select Group | `workshop` |
| Row Level Filter | `station_id IN (SELECT station_id FROM cdp_workshop.station_assignment WHERE user_name = current_user())` |

- Do not reference `meter_readings` in the subquery.
- `current_user()` must equal the `user_name` values loaded in 2.2.
- An invalid expression makes the whole query fail: test with a participant account first.
- Expected: 2 stations in `GROUP BY station_id`, matching the participant's rows in `station_assignment`; `COUNT(*)` is 14 or 16 depending on bucket (see table in section 2).

### 3.4 P4 — deny on `customer_master` (lab section 5)

1. Step 1 (first query, 5 rows with `iban_last4`): the allow from P1 is enough.
2. Step 2 (second query, permission denied): create `cdp_workshop_customer_master_deny`: db `cdp_workshop`, table `customer_master`, column `*`; Deny Conditions: group `workshop`, permission `select`. Optionally add your trainer user under Allow Exceptions.

Deny wins over allow for the same user and resource.

### 3.5 P5 — audit (lab section 6)

No policy to create. Make sure Ranger audit to Solr/HDFS is enabled for the Hive service, otherwise **Audit → Access** stays empty. Participants need events to find: a denied one (section 1 or 5) and an allowed one (section 2). Masked and filtered queries show as **allowed** `select`.

### 3.6 Wrap-up prerequisites (lab section 7)

- The `INSERT` into `cdp_workshop.meter_readings` must fail: no insert/update permission for `workshop` on `cdp_workshop`.
- `CREATE DATABASE ${ws_user}` plus the CTAS must succeed: participants need the right to create and write their own database/location (usually already covered by the default Hive/HDFS "own database" policies; if not, add an allow for `{USER}` on db `{USER}` with all permissions and a matching HDFS policy).

---

## 4. Verify and reset

- Before the session: run [`verify.hql`](verify.hql) and the checks in 2.3.
- After applying P1–P3: run `lab/check.sh` with a participant account; it must pass.
- Between cohorts, disable policies in this order: P4 deny, P3, P2 (all three), P1 last (restores the section 1 baseline).
- Full cleanup: [`teardown.hql`](teardown.hql) (drops the module's tables including `workshop_users`, but keeps the shared database `cdp_workshop`), then remove or disable the lab policies in Ranger.
