# Trainer notes — Module 02 YARN

## Suggested timing (~80 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | RM / NM / container; contrast with HDFS (storage vs compute) |
| 10–15 | Demo `yarn node -list`; optional RM UI |
| 15–22 | Participants: sections 1–2 (nodes, queues, list) |
| 22–35 | Sections 3–4 MapReduce wordcount + status/logs |
| 35–45 | Section 5 ApplicationMaster (two terminals, running `pi`) |
| 45–52 | Section 6 Tez wordcount (same file) |
| 52–60 | Section 7 MR vs Tez comparison; collect numbers on the whiteboard |
| 60–68 | Section 8 Spark linecount |
| 68–73 | Section 9 relate + `check.sh` |
| 73–80 | Section 10 (optional, fast groups) or debrief; otherwise run it as a group demo |

## Check-question talking points

1. **Full cluster (section 1):** Apps queue; back-pressure affects SLA for daily grid batch loads.  
2. **Workshop queue (section 2):** Dedicated queue prevents one tenant from starving others; document the queue name on the whiteboard.  
3. **Failed map (section 4):** Check input path and HDFS ACLs first, then YARN status (`yarn application -status`), then container logs.  
4. **ApplicationMaster (section 5):** The RM only schedules containers; the AM is per-application code that negotiates containers, launches tasks via NodeManagers, retries failed tasks, and reports progress. Putting it in a container keeps the RM small and lets each engine bring its own logic. If the AM container dies, YARN starts a new attempt (`yarn.resourcemanager.am.max-attempts`, MapReduce AM recovers completed tasks); if all attempts fail, the application fails. If a task container dies, only the AM reruns that task.  
5. **MR vs Tez (section 7):** see below.  
6. **Requests that do not fit (section 10):** see below.  
7. **Shared platform (section 9):** Without shared YARN/HDFS the same input files (and later the pilot CSVs) would be copied per engine; governance (Ranger) and lineage would have to be maintained per silo.

## Requests that do not fit (section 10)

Three situations, all with a "stuck" job — make participants name them:

| Request | Result | How it looks |
|---------|--------|--------------|
| Above scheduler maximum (`yarn.scheduler.maximum-allocation-mb`) | Rejected or killed immediately | Console error about invalid resource request / maximum allowed allocation |
| AM larger than what the queue or any node can give | `ACCEPTED`, never starts | No attempt/AM container; diagnostics mention the AM not yet activated or waiting for resources |
| Map containers larger than free capacity, but within scheduler maximum | AM `RUNNING`, job stays at 0% | AM container exists, no map containers; maps wait |

The exact outcome depends on your cluster limits, so **check them before the session** (scheduler maximum, node size, workshop queue capacity and maximum capacity) and have the winning values ready (for example one that is just above the scheduler maximum). The ×4 sequence in the lab usually crosses the limit within 3–4 runs. Pending requests hold no resources, so a stuck job does not block others, but remind participants to `-kill` it. Leftover `QuasiMonteCarlo_…` directories from killed jobs are listed in troubleshooting.

## MR vs Tez comparison (section 7)

Both runs do the same word count on the same file. Collect each participant's numbers on the whiteboard and discuss the spread.

What participants usually see on a small file:

- **ApplicationMaster:** both engines start one AM container (`…_000001`) — start-up cost is similar, so elapsed time is close and can even favour MapReduce on a tiny input. Say this openly; do not oversell Tez on a 1-stage toy job.  
- **Containers:** MapReduce launches separate containers for map and reduce tasks; Tez runs tasks in a DAG and can **reuse containers** within the application, so container count is often lower.  
- **Aggregate resource allocation:** reflects how long containers were held (MB-seconds, vcore-seconds). Compare it with elapsed time.  
- **UI view:** MapReduce shows jobs with map/reduce tasks; Tez shows one DAG with vertices.

Where the gap grows (and why Hive moved to Tez):

- **Multi-stage jobs:** MapReduce chains jobs and writes intermediate results to HDFS between them; Tez runs the whole DAG in one application and streams between vertices. Use the stretch task (`orderedwordcount`, 3 vertices) as the live example.  
- **Interactive latency:** fewer container start-ups per query.

If numbers look odd (Tez slower, large variance): another participant's job was queued, or the first Tez run paid for localizing the Tez libraries. Re-running once usually removes the effect — a good talking point about measuring on shared clusters.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| Example JAR paths differ | Lab hardcodes the CDP parcel paths; verify `hadoop-mapreduce-examples.jar` and `tez-examples.jar` on the edge node before the session and tell participants the right path |
| Tez JAR missing on older layouts | Skip sections 6–7; show the comparison from the RM UI using a Hive query on Tez instead |
| `-show_application_log_info` unsupported | Older client: participants count containers in the RM UI (application → attempt → containers) |
| Output dir exists | Troubleshooting lists the `-rm -r` commands; remind after failed reruns |
| Spark cluster mode | Lab uses **cluster** deploy mode: driver output is only in `yarn logs` — that is intentional (section 8) |
| `pi` finishes before participants can inspect the AM | Tell them to raise the second number (samples per map) or start it in terminal 1 before reading section text |
| `yarn container -signal` unavailable | AM-kill demo needs Hadoop 3.1+; otherwise show attempts in the RM UI only |
| Input text missing | `setup.sh` uploads `assets/die-verwandlung-kapitel-1.txt` to `${WORKSHOP_ROOT}/02-yarn/input`; re-run it with `WORKSHOP_LOCAL` set |
| Why not the use-case CSV? | Word count on a CSV counts every row as one "word" (no spaces). The text is a deliberate exception to the "real workshop data" rule — say so. The text is public domain (Kafka, *Die Verwandlung*, Project Gutenberg #22367, chapter I) |
| Words with punctuation counted separately | Intended: the example tokenizes on whitespace only — talking point in section 3 |

## Admin

Run [setup/setup.sh](../setup/setup.sh) after bootstrap. `WORKSHOP_LOCAL` must reference the repo so `spark_linecount.py` uploads to HDFS.

## After module

Preview module 03: Hive queries compile to Tez DAGs — the container reuse and single-application DAG you just measured is the reason.
