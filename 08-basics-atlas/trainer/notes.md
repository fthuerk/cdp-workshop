# Trainer notes — Module 08 Atlas (UI)

**Dry-run:** complete sections 1–6 with a participant account; capture screenshots for `lab/img/` if you want embedded images in the lab.

## Suggested timing (~20 min)

| Minutes | Activity |
|---------|----------|
| 0–2 | Section 1: database, external staging, CTAS source (~500 rows) |
| 2–6 | Section 2: Atlas search and entity detail (while hook catches up) |
| 6–8 | Section 3: two CTAS children |
| 8–13 | Section 4: downstream/upstream lineage, process node |
| 13–17 | Section 5: `<your_username>_PII` classification and propagation |
| 17–20 | Section 6: glossary term **Active Power** assignment |
| +0 | Final check question; optional `check.sh` |

If Atlas is slow, run section 3 immediately after section 1 and teach section 0 during the wait.

## Pre-session Atlas prep

- Glossary **Metering**, category **Consumption**, term **Active Power** (definition: active power at the meter, kW).  
- Optional: pre-create empty classification template; participants still create **`<your_username>_PII`**.  
- Confirm **classification propagation** is on if you demo tags on child tables.

## Check-question answers

1. **Atlas vs data (section 2):** Atlas holds metadata and lineage; HDFS holds files.  
2. **Final wrap-up:** Downstream tables **`atlas_meter_daily`** and **`atlas_meter_anonymized`** depend on **`atlas_meter_src`**; **Lineage** (downstream from source) shows impact.

## Cut for time (see demos.md)

Advanced search DSL, Audits tab, REST API, deleted-entity lineage, custom attributes, multi-hop optional stretch.

## Admin

[setup/setup.sh](../setup/setup.sh) copies the landisgyr sample CSV to `${WORKSHOP_ROOT}/08-atlas/data/`.
