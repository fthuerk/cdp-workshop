# Trainer setup and cleanup — Module I2 Atlas

Participants may not be allowed to create Atlas types or glossaries, so the trainer creates the shared objects once before the session.

Replace `ATLAS` with the Atlas URL from the Knox home page and use an Atlas admin user (`-u admin`) or a Kerberos ticket (`--negotiate -u :`).

## Before the session

### 1. Classification `PII` (propagation on)

UI: **Classifications → Create** → name `PII`, description `Personally identifiable / sensitive data`.

Or via REST:

```bash
curl -k -u admin -H 'Content-Type: application/json' -X POST "ATLAS/api/atlas/v2/types/typedefs?type=classification" -d '{
  "classificationDefs": [{
    "name": "PII",
    "description": "Personally identifiable / sensitive data",
    "superTypes": [],
    "attributeDefs": []
  }]
}'
```

Classification propagation is a property of the **assignment** (default **on** in the UI: "Propagate" toggle). You attach the tag in the UI (step 4 below), so confirm the toggle is on by default in your Atlas version during the dry run. If the tag does not reach the CTAS children, check that propagation is enabled in the Atlas configuration.

### 2. Glossary `Metering`

**What it is.** The business glossary is a controlled vocabulary kept separate from the technical metadata. It lets the lab link a business word ("Active Power") to a technical column (`active_power_kw`). Lab section 7 shows this: participants assign the term to the column, then find the column from the term, and the table from the column.

The glossary has three levels:

| Level | Purpose | In this lab |
|-------|---------|-------------|
| **Glossary** | Top-level container, usually one per domain or team. Terms and categories live inside exactly one glossary. | `Metering` |
| **Category** | Folder for grouping terms, like a topic. It cannot be assigned to tables or columns. Categories can be nested. | `Consumption` |
| **Term** | The actual business concept with a definition. **Only terms are assigned to entities** (tables, columns). A term can sit in one or more categories. | `Active Power` |

Rule of thumb: the **term** is what participants assign; the **category** only organizes terms in the tree. The lab would work without the category, but it shows the Glossary → Categories → Terms structure from section 7.

**How to create it (Atlas UI, about 3 minutes):**

1. Open Atlas → **Glossary** (left navigation). Click **+** (Create glossary).
2. Name `Metering`, short description `Metering and consumption terms`. Save.
3. Select `Metering`. Switch to the **Category** view/tab (toggle next to "Terms") and click **+** (Create category). Name `Consumption`, description `Terms about energy consumption`. Save.
4. Switch back to the **Term** view and click **+** (Create term).
   - Name: `Active Power`
   - Short description: `Instantaneous active power at the meter, in kW`
   - Category: `Consumption` (select in the term's **Categories** field, or after saving, open the term and add the category)
   - Save.
5. Verify: open the term. You see the definition, and the tabs for assigned entities and related terms are empty. They fill when participants assign it.

Exact button labels vary slightly by Atlas version.

Or via REST (creates glossary, category, and term in order; the response of each call contains the `guid` needed by the next):

```bash
# 1. glossary -> note "guid" as GLOSSARY_GUID
curl -k -u admin -H 'Content-Type: application/json' -X POST "ATLAS/api/atlas/v2/glossary" \
  -d '{"name":"Metering","shortDescription":"Metering and consumption terms"}'

# 2. category -> note "guid" as CATEGORY_GUID
curl -k -u admin -H 'Content-Type: application/json' -X POST "ATLAS/api/atlas/v2/glossary/category" \
  -d '{"name":"Consumption","shortDescription":"Terms about energy consumption","anchor":{"glossaryGuid":"GLOSSARY_GUID"}}'

# 3. term in that category
curl -k -u admin -H 'Content-Type: application/json' -X POST "ATLAS/api/atlas/v2/glossary/term" \
  -d '{"name":"Active Power","shortDescription":"Instantaneous active power at the meter, in kW","anchor":{"glossaryGuid":"GLOSSARY_GUID"},"categories":[{"categoryGuid":"CATEGORY_GUID"}]}'
```

Participants only need to **assign** the term (permissions in section 3 below), not create it.

### 3. Permissions (Ranger → `cm_atlas` / Atlas service)

Participants need, on **their own** Hive entities (`hive_table`, `hive_column`, `hive_db` in their database):

- `entity-read`
- `entity-update-business-metadata` is **not** needed
- Glossary term assignment: `add-relationship` / `remove-relationship` for `AtlasGlossarySemanticAssignment`, plus read on the glossary term

They do **not** need `type-create`.

Also give participants `entity-read` on the entities of database `cdp_workshop`, so they can open the central table and see its tags in lab sections 5 and 6. They only read tags, so they need neither `entity-add-classification` nor `entity-remove-classification`.

### 4. Central table with `PII` tags (lab section 6)

**What it does.** `cdp_workshop.meter_readings` is the shared table from I1-basics-ranger, reused as the central source. Lab section 1 copies its measurement columns with CTAS, and section 6 copies it again including the customer columns. The `PII` tags on `customer_name` and `customer_email` propagate along column lineage to those copies, and one Ranger tag-based policy then masks the tagged columns everywhere.

**Ranger start state for this lab.** The I1 policies on `meter_readings` would interfere: resource-based masking (`cdp_workshop_mask_*`) and the row filter (`cdp_workshop_rows`) make the CTAS copy masked or filtered data, and the `customer_master` deny is irrelevant here. Before this lab keep only the allow policies (`cdp_workshop_db_use`, `cdp_workshop_read`) enabled and **disable** the masking policies and the row filter. If I1 is not part of the cohort, create just those two allow policies (see I1 `setup/setup.md`).

1. Run [`setup.hql`](setup.hql) in Hue as the trainer/admin user. It creates `cdp_workshop.meter_readings` with the 30 rows if it does not exist yet, and reloads the rows otherwise. It is the same definition as in I1 `setup.hql`, so either file can run first; the table entity (and the tags on it) are kept.
2. Wait for the table to appear in Atlas (up to one minute). In the session you do the next step live as the section 5 demo; do it in advance only as a fallback or for the dry run. Attach `PII` to the two columns `customer_name` and `customer_email`, with propagation on.

   UI: open the `hive_table` `meter_readings` → **Schema** → column → **Classifications +** → `PII`, leave **Propagate** checked.

   Or via REST (get the column GUID first; `CLUSTER` is the cluster name in the qualified name, visible on the table entity):

   ```bash
   curl -k -u admin "ATLAS/api/atlas/v2/entity/uniqueAttribute/type/hive_column?attr:qualifiedName=cdp_workshop.meter_readings.customer_name@CLUSTER"

   curl -k -u admin -H 'Content-Type: application/json' -X POST "ATLAS/api/atlas/v2/entity/guid/<column_guid>/classifications" \
     -d '[{"typeName":"PII","propagate":true}]'
   ```

   Repeat for `customer_email`.

   Tag the **columns**, not the table: Ranger masks per column, and a table-level tag does not reliably mask individual columns. Column-level propagation works because the Hive hook records column lineage for CTAS (you see `hive_column_lineage` processes in the lab section 4 screenshots).
3. Participants read the table through the I1 allow policy `cdp_workshop_read` (db `cdp_workshop`, table `meter_readings`, group `workshop`, `select`) plus `cdp_workshop_db_use`; no extra policy is needed.

### 5. Ranger tag-based masking policy (lab section 6)

**Prerequisites** (check once, they are cluster configuration):

- Ranger **Tagsync** is running (Cloudera Manager → Ranger → Instances).
- A Ranger **tag service** exists, usually `cm_tag`, and the Hive service (`cm_hive`) is linked to it: **Access Manager → Hive → edit service `cm_hive` → Select Tag Service**.
- Hive component of the tag service is enabled. Tags flow Atlas → Kafka → Tagsync → Ranger, usually within a minute.

**Policy (created in Ranger → Access Manager → Tag Based Policies → `cm_tag`):**

| Field | Value |
|-------|-------|
| Tab | **Masking** → **Add New Policy** |
| Policy Name | `PII_mask` |
| TAG | `PII` |
| Select Group | `workshop` |
| Component Permissions | Hive → `select` |
| Select Masking Option | `Redact` (letters become `x`, e.g. `Xxxx Xxxxx`; `Nullify` gives `NULL`, `Hash` gives stable values) |

**Why masking and not deny.** A deny policy on the tag makes `SELECT *` fail for everybody with a permission error on the tagged columns, and participants cannot see anything of their table. Masking keeps the table queryable and shows the effect column by column. A deny alternative exists (tab **Access** → deny condition for group `workshop`, Hive `select`) if you want to demonstrate "cannot be accessed".

**Timing in the session.** Create the policy **before** the session but keep it **disabled** (toggle on the policy list). In lab section 6 step 3, enable it. Reason: if the mask is already active when participants run the CTAS in step 1, their copy stores redacted values and the "readable before, masked after" comparison no longer works. Enable the policy only after everyone has run step 1, and disable it again after the session. The lab text marks this with a STOP box after step 1; ask participants to confirm that their table exists before you enable it (for example: `SHOW TABLES IN <user> LIKE 'atlas_customer_copy'` for a few users, or a show of hands).

**Test with a participant account, not as an admin.** Hive admins bypass masking.

### 6. Dry run with a participant account

Open `meter_readings` and confirm the `PII` tags are visible (lab section 5), assign `Active Power` and remove it again. Then run lab section 6: CTAS from `cdp_workshop.meter_readings` (sections 1 and 6), check that `PII` appears on the columns of the copy, enable `PII_mask`, and confirm `customer_name` and `customer_email` are masked in both tables. If any step fails with `403`, fix the Ranger policy before the session. If the tag does not appear on the copy, check propagation (section 1) and the column lineage of the CTAS. If the masking does not apply, check Tagsync and the tag service link (section 5).

## After the session

Participants remove their own tag and term and drop their tables (lab section "Cleanup"). Then the trainer:

### 1. Find leftover assignments

Search Atlas for classification `PII` (include **deleted** entities) and for term `Active Power`.

### 2. Purge deleted entities

Dropped Hive tables stay as `DELETED` entities in Atlas, and a classification cannot be deleted while entities still carry it. Purge them (admin only):

```bash
# GUIDs of deleted hive_table entities carrying PII
curl -k -u admin "ATLAS/api/atlas/v2/search/basic?classification=PII&excludeDeletedEntities=false&limit=1000"

curl -k -u admin -H 'Content-Type: application/json' -X PUT "ATLAS/api/atlas/admin/purge/" -d '["<guid1>","<guid2>"]'
```

For active entities someone forgot (participant tables only, not `cdp_workshop.meter_readings`), remove the tag:

```bash
curl -k -u admin -X DELETE "ATLAS/api/atlas/v2/entity/guid/<guid>/classification/PII"
```

### 3. Ranger tag policy and central table

- Disable the Ranger tag policy `PII_mask` again, so the next session starts with readable copies.
- Keep `cdp_workshop.meter_readings` and its `PII` tags for the next session and for demos. Do not remove those tags in the clean-up above.
- Only if you also remove the classification below: first remove `PII` from the two columns of `meter_readings`, because a classification cannot be deleted while it is assigned.

### 4. Remove shared objects (only if you will not reuse them)

```bash
curl -k -u admin -X DELETE "ATLAS/api/atlas/v2/types/typedef/name/PII"
```

Glossary: UI **Glossary → Metering** → delete terms, category, then glossary. Keep it if the next cohort starts soon.

### 5. Hive

Participant databases are shared with other modules; drop them only at the end of the whole workshop:

```sql
DROP DATABASE IF EXISTS <username> CASCADE;
```
