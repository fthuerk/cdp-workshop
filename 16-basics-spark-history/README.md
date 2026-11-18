# Module 16 — Basics: Spark History Server

How to read what Spark did with the grid monitoring pilot data: you run **one** Spark application in nine small steps (read, filter, shuffle, join, cache, write, fail) and, after each step, look it up in the Spark History Server. You learn to find jobs, stages and tasks, to read the SQL / DataFrame plans, and to link every number in the UI back to the line of code that caused it.

**Estimated time:** ~75 minutes (core ~65 min + stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`)
- The Spark History Server URL from your handout (or the link in Cloudera Manager under **Spark 3 → Spark3 History Server Web UI**)
- **Either** `pyspark3` on the edge node **or** a Jupyter notebook on your laptop with `sparkmagic` and the Livy URL from your handout (set up as in [module 09, section 6](../09-basics-livy/lab/lab_basics_livy.md))

## Learning goals

After this module you can:

- Find your application in the History Server, tell **incomplete** from **completed** applications, and explain how the UI is rebuilt from the event log
- Read a **job** (stages, event timeline, DAG), a **stage** (tasks, summary metrics, shuffle read/write) and a **task** (duration, attempt, error)
- Explain why a `count()` runs in two stages, why a shuffle starts a new stage, and why `inferSchema` adds a job you did not ask for
- Read the **SQL / DataFrame** plan graph and match its nodes (`FileScan`, `Filter`, `HashAggregate`, `Exchange`, `BroadcastHashJoin`) to `explain()` output
- Recognize a skewed stage from the min / median / max task times, and compare a broadcast with a sort-merge join
- Find a cached DataFrame in the **Storage** tab and a failed job with its task attempts
- Link UI rows back to code with job group descriptions, partition counts and a job-id ledger

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Driver, executors, jobs, stages, tasks; event log and History Server (slides: [slides/spark-history](../slides/spark-history/README.md), about 10 min) |
| Core lab | [lab_basics_spark_history.md](lab/lab_basics_spark_history.md) sections 0–10 |
| Alternative client | [lab/notebooks/spark_history_sparkmagic.ipynb](lab/notebooks/spark_history_sparkmagic.ipynb): the same steps from a laptop notebook via Livy + `sparkmagic` |
| Stretch | [lab_basics_spark_history.md](lab/lab_basics_spark_history.md) stretch |

## Screenshots

The lab marks every place for a screenshot with a `SCREENSHOT` note. Put the image files into [lab/images/](lab/images/) under the file name given in the note.

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
```

No module setup script: the lab reads the shared sample CSVs from `00-setup` and writes only to `/user/<participant>`. The History Server must be running and the event log directory (`spark.eventLog.dir`) readable by the History Server.

## Next module

[06-basics-spark](../06-basics-spark/README.md) (the pipeline behind the steps) or [09-basics-livy](../09-basics-livy/README.md) (Spark behind Knox)

---
*The generation of these labs was supported by AI.*
