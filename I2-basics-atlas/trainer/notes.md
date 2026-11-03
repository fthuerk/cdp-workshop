# Trainer notes — Module I2 Atlas (UI)

**Dry-run:** complete sections 1–7 with a participant account; capture screenshots for `lab/img/` if you want embedded images in the lab.

## Suggested timing (~25 min)

| Minutes | Activity |
|---------|----------|
| 0–2 | Section 1: database, managed source table via CTAS from the shared `cdp_workshop.meter_readings` (30 rows) |
| 2–6 | Section 2: Atlas search and entity detail (while hook catches up) |
| 6–8 | Section 3: two CTAS children |
| 8–13 | Section 4: downstream/upstream lineage, process node |
| 13–15 | Section 5 (instructor demo): you attach `PII` to `customer_name` / `customer_email` of `cdp_workshop.meter_readings` live; participants only watch and check |
| 15–22 | Section 6: CTAS from tagged central table, tag arrives on the copy, **you enable `PII_mask` (Redact)** only after everyone confirmed their `atlas_customer_copy` exists, re-run the query |
| 22–25 | Section 7: glossary term **Active Power** assignment |
| +0 | Final check question; optional `check.sh` |

If Atlas is slow, run section 3 immediately after section 1 and teach section 0 during the wait.

## Pre-session Atlas prep

Follow [../setup/setup.md](../setup/setup.md): create classification **`PII`** (propagation on), glossary **Metering** with term **Active Power**, and verify participant permissions in Ranger. Participants only look at the tags and assign the glossary term; they create or attach nothing for classifications. For sections 5 and 6: run `setup/setup.hql`; in section 5 you tag the columns `customer_name` and `customer_email` of `cdp_workshop.meter_readings` with `PII` live (section 6 needs the tags before participants run their CTAS; if you skip the live demo, attach them beforehand); create the tag-based masking policy `PII_mask` **disabled**. Enable it live in section 6 step 3 (earlier, the CTAS would copy masked values).

## Post-session cleanup

See the trainer cleanup section in [../setup/setup.md](../setup/setup.md).

## Check-question answers

1. **Atlas vs data (section 2):** Atlas holds metadata and lineage; HDFS holds files.  
2. **Section 6 check question:** The policy names only the classification `PII` (neither the central table nor the copy). A new table created tomorrow from `meter_readings` inherits the tag by propagation and is masked automatically.
3. **Final wrap-up:** Downstream tables **`atlas_meter_daily`** and **`atlas_meter_anonymized`** depend on **`atlas_meter_src`**; **Lineage** (downstream from source) shows impact.

## Cut for time (see demos.md)

Advanced search DSL, Audits tab, REST API, deleted-entity lineage, custom attributes, multi-hop optional stretch.

## Admin

`setup/setup.hql` makes sure the shared table `cdp_workshop.meter_readings` exists (same table and rows as I1-basics-ranger, either setup can run first). The lab's own tables are managed tables at the default location, so only the Hive policies on personal databases are needed (no URL or extra HDFS policies). **Ranger start state:** the I1 masking policies, row filter and `customer_master` deny must be disabled while this lab runs, otherwise the CTAS copies masked or filtered data (see `setup/setup.md`). Atlas prerequisites are in `setup/setup.md`.
