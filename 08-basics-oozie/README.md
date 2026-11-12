# Module 08 — Basics: Oozie in Hue

A guided tour through the Oozie editors in Hue. You build a **workflow**, a **time-based coordinator** and a **data-triggered coordinator** (which loads a daily Hive partition) with the mouse, run them, and then open the generated XML to see what Hue wrote for you. You type no XML in sections 0–5. A final exercise (section 6) goes the other way: you write a small workflow with a Spark and a Hive action by hand, deploy the XML to HDFS and run it with the `oozie` command.

A whole pipeline written by hand, with Hive and Spark actions, is module [11-advanced-oozie](../11-advanced-oozie/README.md).

**Estimated time:** ~95 minutes (workflow ~25 min, coordinators ~35 min, wrap-up ~10 min, CLI exercise ~25 min).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (workshop root and sample data exist)
- Hue URL and login from your handout (the same user as `WORKSHOP_USER`)
- Sections 0–5 need no terminal. Section 6 (exercise) uses a terminal on the edge node, a valid Kerberos ticket and the Oozie URL from your handout

## Learning goals

After this module you can:

- Find the **Workflow** and **Schedule** editors and the **Job Browser** in Hue
- Build a workflow with a shell action and an fs action, and explain start, action, **kill** and end nodes
- Read the generated `workflow.xml` and `job.properties`-style parameters and map each UI field to an XML element
- Create a **time-based coordinator**, and explain frequency, start/end and nominal time
- Create a **data-triggered coordinator** with a dataset and a `_SUCCESS` done-flag that runs a Hive action to add a daily partition, and read `coordinator.xml`
- Follow workflows and coordinator actions in the Job Browser, and kill what you started
- Write a workflow with a `spark3` and a `hive2` action by hand, deploy it to HDFS and run it with the `oozie` command, with the CSV folder, database and table names as parameters

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Server, launcher, workflow vs coordinator; what Hue generates and where it stores it |
| Core lab | [lab_basics_oozie.md](lab/lab_basics_oozie.md) sections 0–5 |
| Exercise | Section 6: `oozie` command, `spark3` and `hive2` action, deployment of the XML |
| Stretch | Fork and join, a second action type (same lab, end) |

## Screenshots

The lab has placeholders for screenshots. The list of files to produce is in [lab/images/README.md](lab/images/README.md).

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls
- [trainer/deep-dive.md](trainer/deep-dive.md) — fs vs. shell actions, `capture-output`, what Hue generates

## Admin (before session)

No module setup is needed. Check that your Hue has the Oozie editors enabled and that the Oozie service is running (see [trainer/notes.md](trainer/notes.md)).

## Next module

[11-advanced-oozie](../11-advanced-oozie/README.md) (the same topics by hand), or [10-advanced-hive](../10-advanced-hive/README.md).

---
*The generation of these labs was supported by AI.*
