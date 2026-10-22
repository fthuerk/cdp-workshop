# Module 08 — Basics: Atlas (UI)

Twenty-minute lab in **Hue** and **Atlas**: create Hive tables, find them in Atlas, build two **CTAS** children, explore **lineage**, add **classifications** (with propagation), and assign a **business glossary** term.

**Estimated time:** ~20 minutes.

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (for Hue if your cluster requires it)
- Atlas and Hue URLs from your handout (typically via Knox)

## Learning goals

After this module you can:

- Explain how the Hive hook publishes table metadata into Atlas
- Search for a `hive_table` entity and read schema and properties
- Interpret **downstream** and **upstream** lineage including process nodes
- Create and assign a **classification** and recognize **propagation** to derived tables
- Assign a **business glossary** term to a column and find entities from the term

## Flow

| Phase | Content |
|-------|---------|
| Core lab | [lab_basics_atlas.md](lab/lab_basics_atlas.md) sections 0–6 |
| Self-check | `./08-basics-atlas/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, glossary prep, cut topics  
- [trainer/demos.md](trainer/demos.md) — optional deep dives (not in the 20 min lab)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./08-basics-atlas/setup/setup.sh
./08-basics-atlas/setup/verify.sh
```

Pre-create glossary **Metering** with term **Active Power** in Atlas if participants cannot create glossaries. Confirm Hive–Atlas hook and classification propagation are enabled.

## Next module

Continue with [07-lakehouse-iceberg](../07-lakehouse-iceberg/README.md) or [10-advanced-hive](../10-advanced-hive/README.md) per your cohort schedule.
