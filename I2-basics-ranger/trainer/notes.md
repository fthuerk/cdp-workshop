# Trainer notes — Module I2 Ranger (Hive)

**Dry-run:** run `setup/setup.sh`, then walk sections 0–7 with a participant account in group **`workshop`**. Create policies in Ranger UI in the order below; disable (do not delete) policies between cohorts when possible.

## Suggested timing (~30 min)

| Minutes | Activity | Your Ranger action |
|---------|----------|-------------------|
| 0–3 | Section 0: orient | Confirm **no** allow on `ranger_lab.meter_readings` yet |
| 3–6 | Section 1: baseline deny | None — participants should fail `SELECT` |
| 6–10 | Section 2: allow | **P1** allow read |
| 10–16 | Section 3: masking | **P2** masking (three columns) |
| 16–22 | Section 4: row filter | **P3** row filter (+ mapping table select in P1) |
| 22–26 | Section 5: deny | **P4** allow then deny on `customer_master` |
| 26–30 | Section 6–7: audit, wrap-up | **P5** show audit; optional CTAS discussion |

Announce each policy change and remind participants to wait **~30 s** before re-running SQL.

## Pre-session

1. `./I2-basics-ranger/setup/setup.sh` and `./I2-basics-ranger/setup/verify.sh`
2. `participants.txt` on the admin host — drives `station_assignment` (two stations per user, rotated across `TS-101`, `TS-102`, `TS-305`, `TS-401`)
3. Every participant in Linux group **`workshop`** (or `WORKSHOP_GROUP` from config)
4. Ranger → **Access Manager** → **Hive** service (often **`cm_hive`** — adjust to your cluster name)
5. Knox links for Hue and Ranger
6. Optional: second browser logged in as Ranger admin; projector on Ranger UI for section 6

**Start state:** no workshop policies on `ranger_lab` (or all lab policies **disabled**). Default cluster policies must not grant participants `SELECT` on `ranger_lab`.

---

## Step-by-step policy creation (Ranger UI)

Navigation (CDP 7.x wording may vary slightly):

**Access Manager → Hive → `<service>` → Add New Policy** (access policies)

For masking and row filters: same service → tabs **Masking** / **Row Level Filter** → **Add New Policy**.

Use **Policy Name** exactly as below so audit discussion is easy (names are arbitrary but stay consistent across runs).

### P1 — Allow read (`ranger_lab_read`)

Create **two** access policies (or one policy with two resource blocks if your UI supports it).

**Policy A — database metadata**

| Field | Value |
|-------|--------|
| Policy Name | `ranger_lab_db_use` |
| Database | `ranger_lab` |
| Table | `*` |
| Column | `*` |
| Allow Conditions → Select Group | `workshop` |
| Permissions | `select`, `read`, `refresh` (add `use` if shown) |

**Policy B — table data**

| Field | Value |
|-------|--------|
| Policy Name | `ranger_lab_read` |
| Database | `ranger_lab` |
| Table | `meter_readings`, `station_assignment`, `customer_master` (three tables — add rows or separate policies per table) |
| Column | `*` |
| Allow Conditions → Select Group | `workshop` |
| Permissions | `select` |

**Participant outcome (section 2):** `SELECT` on `meter_readings` returns 30 rows; clear PII columns.

**Wait:** ~30 s after Save.

---

### P2 — Column masking

On the Hive service, open tab **Masking** → **Add New Policy** for each column (or combine columns that share the same mask type if your version allows).

**P2a — `customer_email`**

| Field | Value |
|-------|--------|
| Policy Name | `ranger_lab_mask_email` |
| Database | `ranger_lab` |
| Table | `meter_readings` |
| Column | `customer_email` |
| Select Group | `workshop` |
| Mask Type | **Mask** with **Partial mask** or **Email mask** (pick the preset closest to “hide local part, show domain” or partial mask) |

**P2b — `device_id`**

| Field | Value |
|-------|--------|
| Policy Name | `ranger_lab_mask_device` |
| Column | `device_id` |
| Mask Type | **Hash** (or **SHA256** if offered) |

**P2c — `customer_name`**

| Field | Value |
|-------|--------|
| Policy Name | `ranger_lab_mask_name` |
| Column | `customer_name` |
| Mask Type | **Nullify** (replace with NULL) |

Leave **P1** allow policies **enabled**. Masking policies add on top of allow.

**Participant outcome (section 3):** same `SELECT` shows hashed / masked / null values; `WHERE customer_email = 'alex.meter@...'` often returns 0 rows.

**Pitfall:** users in **Hive Admin Users** bypass masking — test with a normal workshop account.

---

### P3 — Row-level filter (`ranger_lab_rows`)

Tab **Row Level Filter** → **Add New Policy**:

| Field | Value |
|-------|--------|
| Policy Name | `ranger_lab_rows` |
| Database | `ranger_lab` |
| Table | `meter_readings` |
| Select Group | `workshop` |
| Row Level Filter | `station_id IN (SELECT station_id FROM ranger_lab.station_assignment WHERE user_name = current_user())` |

**Requirements:**

- **P1** must grant `SELECT` on **`station_assignment`** (included in policy B).
- Do **not** reference `meter_readings` inside the subquery.
- `current_user()` must match the short name participants type in `${ws_user}`.

**Participant outcome (section 4):** `GROUP BY station_id` shows 1–2 stations; `COUNT(*)` is well below 30.

**Pitfall:** if filter expression is invalid, HS2 may fail the query entirely — test with your account first.

---

### P4 — Deny on `customer_master`

**Step 1 — Allow (section 5 first query)**

If P1 already allows `customer_master`, skip. Otherwise add allow:

| Policy Name | `ranger_lab_customer_master_allow` |
| Table | `customer_master` |
| Group | `workshop` |
| Permission | `select` |

**Step 2 — Deny (section 5 second query)**

Create policy **`ranger_lab_customer_master_deny`**:

| Field | Value |
|-------|--------|
| Database | `ranger_lab` |
| Table | `customer_master` |
| Column | `*` |

Enable **Deny All Other Accesses** *or* open **Deny Conditions** (toggle **Enable Deny Conditions** if the tab is hidden):

| Deny Conditions | |
|-----------------|--|
| Select Group | `workshop` |
| Permissions | `select` |

Optional **Allow Exceptions:** add your trainer admin user if you still need to read the table for demos.

**Participant outcome:** first `SELECT` succeeds (5 rows); after deny, permission error.

**Talking point:** deny evaluated before allow → deny wins for `workshop`.

---

### P5 — Audit (section 6)

**Ranger → Audit → Access**

Demo filters:

- User = participant short name
- Resource contains `meter_readings` or `customer_master`
- Result = Allowed / Denied

Point at **policy id**, **access type**, **resource path**, **client IP**, **event time** aligned with Hue runs.

Masked queries usually audit as **allowed** `select` — masking is not the same as deny.

---

## Reset between cohorts

| Policy | Action |
|--------|--------|
| P4 deny | Disable or delete first |
| P3 row filter | Disable |
| P2 masking | Disable all three |
| P1 allow | Disable last (restores section 1 baseline) |

Alternatively run `setup/teardown.sh` and recreate policies from scratch.

---

## Check-question answers

1. **Section 1 — Hive vs HDFS:** Hive/Ranger authorization on the metastore/table resource; participants did not read HDFS directly.
2. **Section 3 — CTAS:** Copies **masked** values visible to the user (what HS2 returned), not underlying clear text.
3. **Section 4 — COUNT(*):** Counts **visible** rows after row filter, not all 30 physical rows.
4. **Section 5 — allow vs deny:** **Deny** wins for matching users/resources.
5. **Wrap-up:** Allow, deny, column masking, row-level filter; audit shows allow/deny events.

## Cut for time

- Section 7 CTAS stretch
- Third masking column (`device_id`) — keep `customer_name` nullify only
- `customer_master` deny — discuss conceptually if UI time is short

## Admin / cluster notes

- Hive service name in Ranger (document in your runbook if not `cm_hive`)
- If `setup.sh` fails on `CREATE TABLE`, kinit as **`hive`** or a DDL-capable admin instead of hdfs-only ticket
- HDFS policies on `ranger_lab` warehouse paths are usually covered by default Hive storage policies — if `SELECT` fails with HDFS ACL errors, add read on the table location for `workshop`
