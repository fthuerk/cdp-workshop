# Trainer notes — Module 11 Oozie

**Dry-run status:** the lab has not been run end to end on the target cluster yet. Do one full run with a normal participant account before the session and note differences under [Pitfalls](#pitfalls). The risky parts are the `hive2` credential (section 4), the `spark3` action with a Python script (section 5) rerun after a fork (section 6) and the `spark3` action that reads and writes the Hive Metastore (section 10).

## Suggested timing (~135 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept (whiteboard): client → Oozie server → database; launcher on YARN; workflow / coordinator / bundle; ShareLib |
| 10–15 | Section 1: paths and `common.properties` (ShareLib: explain in concept slide; optional live `oozie admin -shareliblist` for admins only) |
| 18–33 | Section 2: hello workflow; **walk the room** at `oozie job -info` and `yarn logs` |
| 33–45 | Section 3: decision, fs, kill; the failing run |
| 45–57 | Section 4: hive2 action, credentials, idempotent rerun |
| 57–67 | Section 5: spark3 action, launcher vs Spark application |
| 67–82 | Section 6: fork/join, deliberate failure, rerun |
| 82–97 | Sections 7–8: coordinators (start 7, work on 8 while it runs, check back) |
| 97–107 | Section 9: monitoring, kill |
| 107–132 | Section 10: own application (participants type three files; most time goes into the first run) |
| 132–135 | `check.sh`; closing discussion ([deep-dive](deep-dive.md) section 8) |

If you run short, drop section 10 (the last section; `check.sh` then reports `csv-load-wf` missing, which is expected), drop section 5 (and the Spark branch of the pipeline stays as a read-only exercise) or skip the Hue view. Do not skip section 3: it carries the control-flow concepts without needing Hive or Spark.

## Pre-session checklist (admin)

1. `./11-advanced-oozie/setup/setup.sh` and `./11-advanced-oozie/setup/verify.sh` (set `OOZIE_URL` in `config.env`). That script runs `oozie admin -status` and `-shareliblist` — **trainer/admin only**, not in the participant lab.
2. **Oozie service healthy** in Cloudera Manager; ShareLib installed with `hive2` and `spark3` (Oozie → Actions → Install Oozie ShareLib; Spark 3 may need Update the Spark3 ShareLib after a Spark 3 parcel change). Optionally dry-run the same commands as a **participant** principal: on most Kerberos clusters any logged-in user may **read** admin status and ShareLib lists; write admin commands (`-sharelibupdate`, purge, and so on) require the Oozie admin group.
3. **hive2 credential enabled:** `oozie.credentials.credentialclasses` must contain `hive2=org.apache.oozie.action.hadoop.Hive2Credentials`. Without it the `hive2` action fails with a Kerberos error.
3a. **Oozie is reached through Knox (Basic auth), not Kerberos.** `OOZIE_URL` is `https://<knox-host>:8443/gateway/cdp-proxy-api/oozie`; participants log in with user name and password by adding `-auth BASIC -username "${WORKSHOP_USER}" -password "${WORKSHOP_PASSWORD}"` to every `oozie` command (for `oozie validate` before the file name). Test `oozie admin -version` with a participant account first. If the TLS certificate of Knox is not trusted on the edge node, set `OOZIE_CLIENT_OPTS="-Djavax.net.ssl.trustStore=..."` for the group (or use `-insecure` in a test). Behind Knox, Oozie itself still runs the actions as the user, so the Kerberos parts (`hive2`/`hcat` credentials, HDFS tokens) are unchanged.
4. **Proxy user rights:** Oozie must be allowed to impersonate workshop users (default on CDP when users are in the proxy groups). Symptom otherwise: error about the Oozie user not being allowed to impersonate.
5. **Handout values** for participants (section 10 additionally reads the Metastore URI and principal from `/etc/hive/conf/hive-site.xml` on the edge node, which must exist there): `OOZIE_URL` (Knox address), HiveServer2 JDBC URL, HiveServer2 principal.
6. **YARN capacity** — see the first pitfall below.
7. **Ranger / HDFS:** same rights as module 04 (database `{USER}`, external tables on `${WORKSHOP_ROOT}/data`) and write access to `/user/<participant>`.
8. Optional for the stretch email action: SMTP settings in Oozie (`oozie.email.smtp.host` and related properties).

## Check-question answers

1. **Server restart (1):** The server keeps no job state in memory that matters: workflow, coordinator and action states are in the Oozie database. After a restart, running jobs continue; the launchers keep running on YARN and report back. This is why the database (not the server) is the thing to back up, and why Oozie HA needs a shared database.
2. **Which user (2):** You. The Oozie server submits as a proxy user (`doAs`) and the launcher container runs under your identity, so HDFS permissions, Ranger policies and Hive authorization see **you**, not `oozie`. Consequence: no shared "oozie user" needs rights on all data; but a scheduled job needs a **service account** (technical user) in production, because it runs as whoever submitted it.
3. **Decision and kill (3):** A decision makes the expected failure ("file not there yet") an explicit, named path with a message in `oozie job -info` and in Hue; the on-call person sees *why* without opening container logs. A script failure shows a launcher exit code and sends you to YARN logs. Also: a decision can route to a wait, an alert or a different branch, not only to `kill`.
4. **INSERT INTO vs OVERWRITE (4):** `INSERT INTO` would add the same rows again with every rerun: counts double, KPIs are wrong, and nobody notices until a report looks odd. Schedulers rerun: after failures, after late data, after a manual `-rerun`. Every step must produce the same result when run twice for the same inputs (overwrite one partition, delete before write, `MERGE`). Link back to module 04 and to Iceberg module 07.
5. **Which application (5):** The Ext ID is the **launcher** application (the Oozie-owned container that runs `spark-submit`). The Spark driver and executors are a second application, `weather-daily`; its ID appears in the launcher's log. For driver errors: launcher log first (it prints the Spark application ID), then `yarn logs` or the Spark History Server for that application.
6. **Rerun and idempotency (6):** `-rerun` with `failnodes=true` runs the nodes that did not finish OK again, but the node that failed may have done part of its work (half-written output). `prepare` blocks and overwrite semantics clean up. Nodes that already succeeded are skipped: a non-idempotent action in the same job that **did** succeed is not repeated, but a rerun of the whole job (not `failnodes`) repeats everything.
7. **Nominal time (7):** The nominal time is the logical slot ("the data of 18:05"), the creation time is when Oozie did it. Naming outputs and partitions by nominal time makes a rerun of slot X write exactly to slot X, no matter when it runs, and catch-up after downtime fills the right slots. `now()` would put a rerun's data into today's partition.
8. **Time vs data trigger (8):** A time trigger starts at 06:00 whether the data is there or not (then it fails or processes yesterday's data). A data trigger starts when the source says it is complete (`_SUCCESS`). Late delivery: the action stays `WAITING` until the file arrives or the `timeout` (minutes) passes, then it is `TIMEDOUT` — that status can feed an alert. The done-flag matters because the folder appears before the last file is complete; `_SUCCESS` is written by Spark/MapReduce at the end, so upstream jobs trigger downstream ones.
9. **Credentials (10):** The launcher runs in a YARN container and has no Kerberos ticket, only delegation tokens. HDFS and YARN tokens come automatically. For the Hive Metastore (`hcat`, needed by the Spark job) and HiveServer2 (`hive2`, needed by the Beeline connection of the Hive action) the workflow must name a credential; the Oozie server then fetches a token on behalf of the user and hands it to the launcher.
10. **External vs. managed (10):** In CDP managed Hive tables are transactional (ACID, ORC). Spark cannot write them natively (that needs the Hive Warehouse Connector), but it reads and writes plain files and external tables without problems. So Spark owns the raw external table and Hive builds the managed table. The reverse would need HWC in the Spark job.

## Pitfalls

- **Launcher starvation / YARN deadlock.** Every action needs a launcher container for as long as the action runs; a Spark action needs a launcher **plus** the Spark application (driver, executor). With ~20 participants submitting at the same time, launchers can fill the queue and leave no room for the Spark applications they wait for: everything sits at `RUNNING`/`ACCEPTED`. Mitigations: a separate queue for launchers (`oozie.launcher.mapreduce.job.queuename` or the `<launcher queue=...>` element), a higher AM share for the queue (`maximum-am-resource-percent`), the Spark `--num-executors 1 --executor-memory 1g` already in the examples, and staggering section 5 and 6 by two groups. Show it in the RM UI if it happens: it is a real production lesson.
- **hive2 `GSS initiate failed`.** Missing `cred=` attribute, wrong principal, or credential class not enabled (checklist item 3).
- **Principal with `_HOST`.** `Hive2Credentials` needs the concrete HiveServer2 principal. If the handout JDBC URL contains `principal=hive/_HOST@REALM`, give participants a separate `HS2_PRINCIPAL` with the real host name.
- **Spark action.** In Cloudera Runtime 7.1.9 the Spark 2 `spark` action is deprecated and disabled by default; use `spark3` with `master` `yarn` and `mode` `cluster`. The Cloudera Runtime and Spark 3 (CDS) versions must match, otherwise classpath errors (`NoSuchMethodError` on commons classes) show up only through Oozie. Python scripts as `<jar>`: if your build cannot find `pyspark` in the launcher, check the Spark 3 ShareLib for the PySpark and Py4J zip files and the Cloudera ShareLib troubleshooting topic.
- **No ResourceManager in the examples.** The `resource-manager` element is optional and omitted, the server uses its default. Reason: participants submit through Knox, which rewrites the job properties `jobTracker` and `nameNode` (a `jobTracker=yarnRM` in `job.properties` shows up as `JOBTRACKER` in the job). If a cluster needs the element anyway, add `<resource-manager>yarnRM</resource-manager>` (the logical ResourceManager name, the value Hue puts into `jobTracker`) to every action; do not take the value from a property called `jobTracker`. `oozie job -configcontent <job-id>` shows what the job really got.
- **Schema versions.** The examples use `workflow:1.0`, `shell-action:1.0`, `hive2-action:1.0`, `spark3-action:1.0`, `coordinator:0.5`. If the cluster's Oozie rejects 1.0 namespaces, use `workflow:0.5`, `shell-action:0.3`, `hive2-action:0.2` (those use `job-tracker`; the examples have no ResourceManager element, so nothing else changes).
- **Coordinator frequency below 5 minutes** is rejected by default (`oozie.service.coord.check.maximum.frequency`). Do not change it for the workshop; the lab uses 5.
- **UTC everywhere.** Coordinator times in the lab are UTC (`timezone="UTC"`, `date -u`). A cohort working across midnight UTC sees a different `${YEAR}${MONTH}${DAY}`.
- **Forgotten coordinators.** A coordinator with a far `end` keeps materializing. Ask everyone for `oozie jobs -jobtype coordinator -filter "status=RUNNING"` at the end; as admin kill leftovers with `oozie job -kill`.
- **Section 4 timing.** `oozie job -run` returns immediately; participants who run the Beeline query before the job is `SUCCEEDED` get an empty or missing table. Say "check `-info` first" twice.
- **macOS edge laptops.** `date -u -d` is GNU syntax. The lab expects the Linux edge node.
- **Section 10 (own application).** Things that differ per cluster:
  - The Spark action reads and writes the Hive Metastore, so it needs the `hcat` credential **and** `hive-site.xml` in the driver (`<file>` in the action). If Spark reports that the database or table cannot be found, or creates a local Derby metastore, `hive-site.xml` did not arrive. If it fails with a GSS error against the metastore, the `hcat` credential is not enabled in `oozie.credentials.credentialclasses`.
  - Some clusters also need the Hive ShareLib for the Spark action: add `oozie.action.sharelib.for.spark3=spark3,hive` to `csv-load.properties`.
  - `/etc/hive/conf/hive-site.xml` must exist on the edge node. If it sits elsewhere (for example under the Spark 3 gateway configuration), tell the group the path.
  - Spark `saveAsTable` without `LOCATION` must create an **external** table on your cluster (check with `DESCRIBE FORMATTED`: `Table Type: EXTERNAL_TABLE`), otherwise the Ranger/HDFS policies of module 06 are not set up. `CREATE TABLE ... AS SELECT` in Hive then creates a **managed** (transactional) table.
  - Spark may infer `ts_utc` as timestamp. Hive reading Spark-written Parquet timestamps can show a time zone shift (see module 14); it does not matter for this exercise.
  - The workflow is idempotent: Spark overwrites its table, Hive drops and recreates the managed table. Participants can rerun it freely.
