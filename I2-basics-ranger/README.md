# Module I2 — Basics: Ranger (Hive policies)

Thirty-minute lab in **Hue** and **Ranger**: shared table `ranger_lab.meter_readings`, then live policy changes (allow, column masking, row-level filter, deny) while participants re-run the same SQL and inspect **audit** logs.

**Estimated time:** ~30 minutes. **Format:** instructor-led (the `I` prefix): the trainer changes the Ranger policies live while you re-run the SQL.

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Module [04-basics-hive](../04-basics-hive/README.md) or enough Hive/SQL comfort to run `SELECT` in Hue
- Valid Kerberos ticket (for Hue if your cluster requires it)
- Hue and Ranger links on the Knox home page (ask your trainer if you cannot find them)
- Admin has run [setup/setup.sh](setup/setup.sh) before the session (creates `ranger_lab` data)

## Learning goals

After this module you can:

- Relate **Ranger** policies to Hive query success and failure
- Distinguish **allow**, **deny**, **column masking**, and **row-level filter** effects on query results
- Explain why **deny** overrides **allow** for the same resource
- Find your own SQL activity in Ranger **Audit → Access**

## Flow

| Phase | Content |
|-------|---------|
| Core lab | [lab_basics_ranger.md](lab/lab_basics_ranger.md) sections 0–7 |
| Self-check | `./I2-basics-ranger/lab/check.sh` (after the trainer has applied the final policies) |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, **step-by-step Ranger policy creation**, check-question answers
- [trainer/demos.md](trainer/demos.md) — optional deep dives (not in the 30 min lab)

## Admin (before session)

1. Run `./I2-basics-ranger/setup/setup.sh` (creates database `ranger_lab`, tables, and `station_assignment` from `00-setup/admin/participants.txt`).
2. Run `./I2-basics-ranger/setup/verify.sh`.
3. Confirm workshop users are in Linux group **`workshop`** (or the value of `WORKSHOP_GROUP` in your `config.env`).
4. Do **not** pre-create the lab Ranger policies — the trainer adds them live during section 1 onward (see [trainer/notes.md](trainer/notes.md)).

Optional: module [I1-basics-atlas](../I1-basics-atlas/README.md) glossary/classification demo pairs well with tag-based policies in [trainer/demos.md](trainer/demos.md).

## Next module

Continue with [I1-basics-atlas](../I1-basics-atlas/README.md), [07-lakehouse-iceberg](../07-lakehouse-iceberg/README.md), or [10-advanced-hive](../10-advanced-hive/README.md) per your cohort schedule.

---
*The generation of these labs was supported by AI.*
