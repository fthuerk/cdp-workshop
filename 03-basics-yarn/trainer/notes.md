# Trainer notes — Module 03 YARN

## Suggested timing (~80 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | RM / NM / container; contrast with HDFS (storage vs compute) |
| 10–15 | Demo `yarn node -list`; optional RM UI |
| 15–22 | Participants: sections 1–2 (nodes, queues, list) |
| 22–35 | Sections 3–4 MapReduce wordcount + status/logs |
| 35–45 | Section 5 ApplicationMaster (two terminals, running `pi`) |
| 45–52 | Section 6 Tez wordcount (same file) |
| 52–60 | Section 7 many small files (MR vs Tez cold vs Tez warm); collect numbers on the whiteboard |
| 60–68 | Section 8 Spark linecount |
| 68–73 | Section 9 relate + `check.sh` |
| 73–80 | Section 10 (optional, fast groups) or debrief; otherwise run it as a group demo |

## Check-question talking points

1. **Full cluster (section 1):** Apps queue; back-pressure affects SLA for daily grid batch loads.  
2. **Workshop queue (section 2):** Dedicated queue prevents one tenant from starving others; document the queue name on the whiteboard.  
3. **Failed map (section 4):** Check input path and HDFS ACLs first, then YARN status (`yarn application -status`), then container logs.  
4. **ApplicationMaster (section 5):** The RM only schedules containers; the AM is per-application code that negotiates containers, launches tasks via NodeManagers, retries failed tasks, and reports progress. Putting it in a container keeps the RM small and lets each engine bring its own logic. If the AM container dies, YARN starts a new attempt (`yarn.resourcemanager.am.max-attempts`, MapReduce AM recovers completed tasks); if all attempts fail, the application fails. If a task container dies, only the AM reruns that task.  
5. **Many small files (section 7):** see below.  
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

## MR vs Tez: many small files (section 7)

**Be honest about cold Tez.** On the single file (sections 3 and 6) a cold direct Tez job is often **slower** than MapReduce: the `yarn jar` client starts a new Tez session and AM every time, and the first run on a node distributes the Tez library tarball (`tez.tar.gz`, ~1.2 GB on this parcel). Do not promise a speed-up there. Hive hides this cost with pre-started sessions (and container reuse across queries).

**Many small files (section 7).** The same word count runs on a folder of ~100 small files (same text, 6 lines each):

- **MapReduce:** one map task per file (a split never spans files) → ~100 map containers, each paying JVM start-up for a few lines of text. Console output shows `Launched map tasks` ≈ number of files.  
- **Tez:** the input is read with **grouped splits** (`tez.grouping.min-size` / `max-size`), so small files are combined into very few tasks — here usually one or a handful, since the whole input is far below the grouping size. Containers are also reused between tasks.  
- **Expected pattern (not yet measured on this cluster):** MapReduce needs ~100+ containers; Tez needs a handful. The first Tez run is slowest (library localization), the second Tez run is clearly faster than the first and normally faster than MapReduce. If participants run at the same time the numbers vary widely — collect them on the whiteboard and discuss why.  
- **Link to the HDFS lab and Hive:** many small files mean many blocks and NameNode entries (HDFS lab) and, for MapReduce, many tasks. Tez split grouping is the reason Hive on Tez copes better with small files, but compaction and sensible file sizes (Hive module) remain the real fix.

The text data and the cut-up files are synthetic on purpose; say so when a participant asks why this is not the smart-meter CSV.

If numbers look odd (Tez slower on both runs, large variance): other jobs queued ahead, or the Tez client is not picking up the cluster Tez configuration (`tez.lib.uris`) — check the `HADOOP_CLASSPATH` line from section 6.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| Example JAR paths differ | Lab hardcodes the CDP 7.3 parcel paths (`lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar`, `lib/tez/bin/tez-examples-*.jar`; the Tez JAR name contains the version, e.g. `0.9.1.7.3.2.20000-258`). `setup/verify.sh` checks both on the edge node — run it before the session |
| Section 7 outcome not measured | Do one dry run: MapReduce vs Tez (cold) vs Tez (warm) on `${WORKSHOP_ROOT}/03-yarn/input-many`. Adjust the file count in `setup.sh` (`split -l 6`) if the contrast is too small (fewer lines per file → more files) |
| Tez split grouping outcome | Tez native `wordcount` should group the small files; confirm the Tez container count after the dry run and adjust the talking points if grouping is configured differently on your cluster |
| Tez direct run not tested | The `HADOOP_CLASSPATH` line in section 6 (Tez conf + `lib/tez/bin/*` + `lib/tez/*`) was derived from the parcel layout and has **not** been run end to end. Do one run with a participant account first; if it needs more jars, extend the line in the lab |
| Tez JAR missing on older layouts | Skip sections 6–7; show the comparison from the RM UI using a Hive query on Tez instead |
| `-show_application_log_info` unsupported | Older client: participants count containers in the RM UI (application → attempt → containers) |
| Output dir exists | Troubleshooting lists the `-rm -r` commands; remind after failed reruns |
| Spark cluster mode | Lab uses **cluster** deploy mode: driver output is only in `yarn logs` — that is intentional (section 8) |
| `pi` finishes before participants can inspect the AM | Tell them to raise the second number (samples per map) or start it in terminal 1 before reading section text |
| `yarn container -signal` unavailable | AM-kill demo needs Hadoop 3.1+; otherwise show attempts in the RM UI only |
| Input text missing | `setup.sh` uploads `assets/die-verwandlung-kapitel-1.txt` to `${WORKSHOP_ROOT}/03-yarn/input`; re-run it with `WORKSHOP_LOCAL` set |
| Why not the use-case CSV? | Word count on a CSV counts every row as one "word" (no spaces). The text is a deliberate exception to the "real workshop data" rule — say so. The text is public domain (Kafka, *Die Verwandlung*, Project Gutenberg #22367, chapter I) |
| Words with punctuation counted separately | Intended: the example tokenizes on whitespace only — talking point in section 3 |

## Admin

Run [setup/setup.sh](../setup/setup.sh) after bootstrap. `WORKSHOP_LOCAL` must reference the repo so `spark_linecount.py` uploads to HDFS.

## After module

Preview module 04: Hive queries compile to Tez DAGs — the container reuse and single-application DAG you just measured is the reason.
