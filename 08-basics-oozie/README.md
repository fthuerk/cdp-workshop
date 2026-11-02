# Module 08 — Basics: Oozie

Scheduling and orchestration for the grid monitoring use case: build a small daily pipeline (check the landing folder, summarize meter data in Hive, summarize operator weather in Spark) as an **Oozie workflow**, then start it on a schedule and when the data arrives with **coordinators**.

**Estimated time:** ~110 minutes (workflows ~70 min, coordinators ~30 min, wrap-up ~10 min; optional Hue view and stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`)
- The `oozie` command on the edge node and the Oozie server URL (from your handout)
- Hive and Spark must be usable with your account (same rights as in the Hive and Spark labs)

## Learning goals

After this module you can:

- Explain the parts of an Oozie application: `workflow.xml` on HDFS, `job.properties` on the edge node, launcher, and why `oozie.use.system.libpath=true` uses the cluster ShareLib
- Write and run a workflow with a shell action; find the launcher on YARN and read its log
- Use **control nodes** (decision, fork, join, kill) and **EL functions** to build a workflow that checks its input and fails with a clear message
- Run **fs**, **hive2** and **spark3** actions, including the credential that a Kerberos cluster needs for Hive
- Read job and action states with `oozie job -info`, and **rerun** only the failed part of a workflow
- Start a workflow with a **time-based coordinator** and explain nominal time and catch-up
- Start a workflow with a **data-triggered coordinator** using a dataset and a `_SUCCESS` done-flag
- Suspend, resume and kill jobs, and name the usual alternatives for new pipelines

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Where Oozie sits (server, database, launcher, YARN); workflow vs coordinator vs bundle; why a scheduler needs idempotent steps |
| Core lab | [lab_basics_oozie.md](lab/lab_basics_oozie.md) sections 1–9 |
| Optional | Hue job browser view (end of section 9) and stretch tasks |
| Self-check | `./08-basics-oozie/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls  
- [trainer/demos.md](trainer/demos.md) — email action, bundle, SLA, Hue editor (trainer-only)  
- [trainer/deep-dive.md](trainer/deep-dive.md) — how Oozie works, action catalog, CDP specifics, Oozie and its successors

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./08-basics-oozie/setup/setup.sh
./08-basics-oozie/setup/verify.sh
```

Set `OOZIE_URL` in `config.env` first so `verify.sh` can check the server and the ShareLib (`hive2`, `spark3`). Details and cluster prerequisites (hive2 credential, YARN capacity for launchers) are in [trainer/notes.md](trainer/notes.md).

## Next module

[10-advanced-hive](../10-advanced-hive/README.md), or the instructor-led modules [I1-basics-atlas](../I1-basics-atlas/README.md) and [I2-basics-ranger](../I2-basics-ranger/README.md).

---
*The generation of these labs was supported by AI.*
