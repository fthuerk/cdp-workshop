# Module 08 — Basics: Oozie in Hue

A guided tour through the Oozie editors in Hue. You build a **workflow**, a **time-based coordinator** and a **data-triggered coordinator** (which loads a daily Hive partition) with the mouse, run them, and then open the generated XML to see what Hue wrote for you. You type no XML.

The same pipeline written by hand, with Hive and Spark actions, is module [11-advanced-oozie](../11-advanced-oozie/README.md).

**Estimated time:** ~70 minutes (workflow ~25 min, coordinators ~35 min, wrap-up ~10 min).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (workshop root and sample data exist)
- Hue URL and login from your handout (the same user as `WORKSHOP_USER`)
- No terminal is required; the optional Kerberos and YARN checks use the edge node

## Learning goals

After this module you can:

- Find the **Workflow** and **Schedule** editors and the **Job Browser** in Hue
- Build a workflow with a shell action and an fs action, and explain start, action, **kill** and end nodes
- Read the generated `workflow.xml` and `job.properties`-style parameters and map each UI field to an XML element
- Create a **time-based coordinator**, and explain frequency, start/end and nominal time
- Create a **data-triggered coordinator** with a dataset and a `_SUCCESS` done-flag that runs a Hive action to add a daily partition, and read `coordinator.xml`
- Follow workflows and coordinator actions in the Job Browser, and kill what you started

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Server, launcher, workflow vs coordinator; what Hue generates and where it stores it |
| Core lab | [lab_basics_oozie.md](lab/lab_basics_oozie.md) sections 0–5 |
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
