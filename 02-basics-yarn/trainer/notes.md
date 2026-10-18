# Trainer notes — Module 02 YARN

## Suggested timing (~70 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | RM / NM / container; contrast with HDFS (storage vs compute) |
| 10–15 | Demo `yarn node -list`; optional RM UI |
| 15–22 | Participants: sections 1–2 (nodes, queues, list) |
| 22–35 | Sections 3–4 MapReduce wordcount + status/logs |
| 35–42 | Section 5 Tez wordcount (same file) |
| 42–52 | Section 6 MR vs Tez comparison; collect numbers on the whiteboard |
| 52–62 | Section 7 Spark linecount |
| 62–70 | Section 8 relate + `check.sh` |

## Check-question talking points

1. **Full cluster (section 1):** Apps queue; back-pressure affects SLA for daily grid batch loads.  
2. **Workshop queue (section 2):** Dedicated queue prevents one tenant from starving others; document the queue name on the whiteboard.  
3. **Failed map (section 4):** Check input path and HDFS ACLs first, then YARN status (`yarn application -status`), then container logs.  
4. **MR vs Tez (section 6):** see below.  
5. **Shared platform (section 8):** Without shared YARN/HDFS the pilot CSVs would be copied per engine; governance (Ranger) and lineage would have to be maintained per silo.

## MR vs Tez comparison (section 6)

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
| Tez JAR missing on older layouts | Skip sections 5–6; show the comparison from the RM UI using a Hive query on Tez instead |
| `-show_application_log_info` unsupported | Older client: participants count containers in the RM UI (application → attempt → containers) |
| Output dir exists | Troubleshooting lists the `-rm -r` commands; remind after failed reruns |
| Spark cluster mode | Lab uses **cluster** deploy mode: driver output is only in `yarn logs` — that is intentional (section 7) |
| No sample CSV in home | Gate: module 01 check or quick `-cp` from `${WORKSHOP_ROOT}/data/landisgyr/…` |

## Admin

Run [setup/setup.sh](../setup/setup.sh) after bootstrap. `WORKSHOP_LOCAL` must reference the repo so `spark_linecount.py` uploads to HDFS.

## After module

Preview module 03: Hive queries compile to Tez DAGs — the container reuse and single-application DAG you just measured is the reason.
