# Module I2 — Basics: Atlas (UI)

Twenty-five-minute lab in **Hue**, **Atlas** and **Ranger**: create Hive tables, find them in Atlas, build two **CTAS** children, explore **lineage**, add **classifications** (with propagation), assign a **business glossary** term, and see a **tag-based Ranger policy** mask a copy of a pre-tagged central table.

**Estimated time:** ~25 minutes. **Format:** instructor-led (the `I` prefix): the trainer drives the session in the UI and you follow along.

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (for Hue if your cluster requires it)
- Atlas and Hue links on the Knox home page (ask your trainer if you cannot find them)

## Learning goals

After this module you can:

- Explain how the Hive hook publishes table metadata into Atlas
- Search for a `hive_table` entity and read schema and properties
- Interpret **downstream** and **upstream** lineage including process nodes
- Read a **classification** on a table column and recognize **propagation** to derived tables
- Assign a **business glossary** term to a column and find entities from the term
- Explain how a **tag-based policy** in Ranger masks every column tagged `PII`, including copies that inherit the tag by propagation

## Flow

| Phase | Content |
|-------|---------|
| Core lab | [lab_basics_atlas.md](lab/lab_basics_atlas.md) sections 0–7 |
| Self-check | `./I2-basics-atlas/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, glossary prep, cut topics  
- [trainer/demos.md](trainer/demos.md) — optional deep dives (not in the 25 min lab)

## Admin (before session)

The lab reads the shared table `cdp_workshop.meter_readings` (same table and rows as [I1-basics-ranger](../I1-basics-ranger/README.md)); [setup/setup.hql](setup/setup.hql) creates it if I1 was not run. Participants build their own managed tables from it, so no extra HDFS paths or Ranger URL policies are needed beyond the Hive policies on personal databases and `select` on `cdp_workshop.meter_readings`. The I1 masking policies, row filter and `customer_master` deny must be disabled during this lab.

Sections 5 and 6 need `PII` tags on the columns `customer_name` and `customer_email` of the shared table, plus a Ranger tag-based masking policy `PII_mask` (kept disabled until the lab step that enables it). Atlas and Ranger setup and cleanup: [setup/setup.md](setup/setup.md). The trainer also pre-creates the shared classification **PII** (propagation on) and glossary **Metering** with term **Active Power**; participants only read the tag and assign the term.

## Next module

Continue with [07-lakehouse-iceberg](../07-lakehouse-iceberg/README.md) or [10-advanced-hive](../10-advanced-hive/README.md) per your cohort schedule.

---
*The generation of these labs was supported by AI.*
