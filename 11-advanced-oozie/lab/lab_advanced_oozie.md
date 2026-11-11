# Oozie hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need one terminal on the edge node. Keep a second one open for sections 7 and 8, where you wait for scheduled jobs.

**Oozie** is the workflow scheduler of the platform. You describe a pipeline as a **workflow** (a graph of actions), start it by hand or let a **coordinator** start it on a schedule or when data arrives. Hive, Spark, shell scripts and HDFS operations all run as **actions** of such a workflow.

The lab builds one small pipeline step by step:

| Sections | You build | Concept |
|----------|-----------|---------|
| 1–2 | Paths and `common.properties`, then `hello` workflow | HDFS application folder, `job.properties`, launcher, job states |
| 3 | `landing-check` workflow | Decision, fs action, kill node, error handling |
| 4–5 | Hive and Spark workflows | `hive2` and `spark3` actions, credentials, parameters |
| 6 | `meter-daily` workflow | Fork and join, failure, rerun |
| 7 | Time-based coordinator | Frequency, nominal time, catch-up |
| 8 | Data-triggered coordinator | Dataset, done-flag, input event |
| 9 | Monitor and clean up | Suspend, resume, kill |

**Files you create.** You write the files of this lab yourself with `vim` (open the file, press `i`, type or paste the content, press `Esc`, then `:wq`). The file contents contain placeholders in angle brackets that you replace with your own values: `<your_user>` (your `WORKSHOP_USER`), `<name-node>` (from `echo "${NAME_NODE}"` in section 1), and the workshop path `/2026_cdp_workshop` (adjust if yours differs). In `vim`, one command replaces all occurrences: `:%s/<your_user>/alice/g` (use your own name).

Set your Kerberos identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`. `OOZIE_LAB` holds the shared example applications on HDFS (the name of the HDFS folder is `11-oozie`). `OOZIE_HDFS` is your own Oozie folder on HDFS, `OOZIE_LOCAL` your working folder on the edge node. `OOZIE_URL` is the Oozie server URL from your handout; the `oozie` command reads it automatically.

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export OOZIE_LAB="${WORKSHOP_ROOT}/11-oozie"
export OOZIE_HDFS="/user/${WORKSHOP_USER}/oozie"
export OOZIE_LOCAL="${HOME}/oozie-lab"
export OOZIE_URL="<oozie-url-from-your-handout>"   # for example https://<host>:11443/oozie
```

Oozie does not process data itself. For every action it starts a small **launcher** application on YARN, and the launcher starts your script, Beeline or `spark-submit`. Everything you know from the YARN, Hive and Spark labs applies here.

---

## 1. Orient — paths and shared job properties

**Goal:** Set the HDFS and edge-node folders you use in every section, and write the shared `job.properties` snippet.

Your instructor confirms that Oozie is running and that Hive and Spark actions are supported on the cluster before you start (that check uses admin tooling, not something you need for the lab).

Oozie never reads files from your edge node while a job runs. Your **application** is a folder on HDFS (`workflow.xml` plus scripts). The **`job.properties`** file stays on the edge node and points Oozie at that folder. For Hive and Spark actions the cluster also uses a shared jar library on HDFS (**ShareLib**); your properties file turns that on with `oozie.use.system.libpath=true` — you do not upload those jars yourself.

Create the folders you need and your local working folder:

```bash
# HDFS: applications, outputs, scratch space
hdfs dfs -mkdir -p "${OOZIE_HDFS}/apps" "${OOZIE_HDFS}/coord" "${OOZIE_HDFS}/out" "${OOZIE_HDFS}/work"

# Edge node: where you keep job.properties files
mkdir -p "${OOZIE_LOCAL}"
cd "${OOZIE_LOCAL}"
```

Workflows need to know where the NameNode, the ResourceManager and HiveServer2 are. Look up the NameNode, take the other values from your handout:

```bash
# NameNode URI of the cluster
export NAME_NODE=$(hdfs getconf -confKey fs.defaultFS)
echo "${NAME_NODE}"

# From your handout
export RESOURCE_MANAGER="<resource-manager-host:port-from-your-handout>"
export HS2_PRINCIPAL="<hiveserver2-principal-from-your-handout>"
```

Write the properties that every job of this lab shares into one file. Later sections copy it and add their own lines. `oozie.use.system.libpath=true` switches the ShareLib on:

```bash
vim common.properties
```

Content of the file (replace the placeholders with the values from your handout and from the `echo` above):

```properties
nameNode=<name-node>
resourceManager=<resource-manager-host:port>
oozie.use.system.libpath=true
database=<your_user>
jdbcURL=<hiveserver2-jdbc-url>
jdbcPrincipal=<hiveserver2-principal>
outputRoot=${nameNode}/user/<your_user>/oozie/out
weatherDir=${nameNode}/2026_cdp_workshop/data/operator_weather
```

Oozie fills `${nameNode}` itself from the line above, so you write the NameNode only once.

**Check question:** Oozie keeps the state of every job in a database. What happens to a running workflow if the Oozie server restarts?

---

## 2. Your first workflow — a shell action

**Goal:** Write, submit and inspect a workflow with one shell action.

An Oozie **application** is a folder on HDFS with a `workflow.xml` and everything the actions need (scripts, jars, SQL). The **`job.properties`** file stays on the edge node: it tells Oozie where the application is and fills the `${...}` variables of the workflow.

Create the script that the action will run:

```bash
mkdir -p "${OOZIE_LOCAL}/hello"
cd "${OOZIE_LOCAL}/hello"
vim hello.sh
```

Content of the file:

```bash
#!/bin/bash
echo "Greeting: $1"
echo "Running on $(hostname) as $(whoami)"
```

Now the workflow. Read it from top to bottom: `start` points to the first node, the action has an `ok` and an `error` transition, `kill` ends the workflow as failed, `end` as succeeded. `<file>` ships the script to the container.

```bash
vim workflow.xml
```

Content of the file:

```xml
<workflow-app name="hello-wf" xmlns="uri:oozie:workflow:1.0">
  <start to="hello"/>
  <action name="hello">
    <shell xmlns="uri:oozie:shell-action:1.0">
      <resource-manager>${resourceManager}</resource-manager>
      <name-node>${nameNode}</name-node>
      <exec>hello.sh</exec>
      <argument>${greeting}</argument>
      <file>hello.sh#hello.sh</file>
    </shell>
    <ok to="end"/>
    <error to="fail"/>
  </action>
  <kill name="fail">
    <message>Shell action failed: ${wf:errorMessage(wf:lastErrorNode())}</message>
  </kill>
  <end name="end"/>
</workflow-app>
```

Check the XML against the schema, then upload the application folder:

```bash
# Syntax check by the Oozie server
oozie validate workflow.xml

# Application folder on HDFS
hdfs dfs -mkdir -p "${OOZIE_HDFS}/apps/hello"
hdfs dfs -put -f workflow.xml hello.sh "${OOZIE_HDFS}/apps/hello/"
```

Create the job properties: the shared file plus the application path and the value for `${greeting}`.

```bash
cd "${OOZIE_LOCAL}"
cp common.properties hello.properties
vim hello.properties
```

Add these lines at the end of the file:

```properties
oozie.wf.application.path=${nameNode}/user/<your_user>/oozie/apps/hello
greeting=Hello grid
```

Submit and start the job in one step. Oozie prints a job ID that ends with `-W` (workflow). Copy it into a variable:

```bash
oozie job -config hello.properties -run
```

```bash
export WF_ID="<job-id-from-the-output>"
```

Look at the job:

```bash
# State of the workflow and its actions
oozie job -info "${WF_ID}"

# What Oozie did, node by node
oozie job -log "${WF_ID}"
```

Repeat `-info` until the status is `SUCCEEDED`. The top block describes the job (status, user, start and end time). The table below lists one row per node:

- **ID** — `<job-id>@<node name>`
- **Status** — `OK` means the node finished, `ERROR` or `KILLED` means it did not
- **Ext ID** — the YARN application of the **launcher** (or `-` for nodes Oozie handles itself)
- **Ext Status** — state of that YARN application
- **Err Code** — short error code when something failed

The output of your script is in the log of the launcher. Take the **Ext ID** of the `hello` row (starts with `application_`) and read its log, as in the YARN lab:

```bash
yarn logs -applicationId "<ext-id-of-the-hello-node>" -log_files stdout
```

You should find your greeting and the host name.

**Check question:** Which user does the script run as, `oozie` or you? Why is that important for HDFS and Hive permissions?

---

## 3. Control flow — decision, fs action and kill

**Goal:** Let a workflow check its input first and end in a clear failure state when the input is missing.

Real pipelines start with a check: has the file arrived? The shared example `landing-check` does exactly that, with no cluster engine involved. Copy it into your home directory and read it:

```bash
hdfs dfs -cp -f "${OOZIE_LAB}/apps/landing-check" "${OOZIE_HDFS}/apps/"
hdfs dfs -cat "${OOZIE_HDFS}/apps/landing-check/workflow.xml"
```

Find three things in the file:

- The `decision` node: the first `case` whose expression is true wins, otherwise `default`. `fs:exists()` and `fs:fileSize()` are **EL functions** that Oozie evaluates itself.
- The `fs` action: `delete`, `mkdir` and `touchz` are done by the Oozie server, no container needed.
- Two `kill` nodes with different messages.

Create the properties. `inputFile` is the smart-meter sample, `workDir` is where the fs action works:

```bash
cd "${OOZIE_LOCAL}"
cp common.properties landing.properties
vim landing.properties
```

Add these lines at the end of the file:

```properties
oozie.wf.application.path=${nameNode}/user/<your_user>/oozie/apps/landing-check
inputFile=${nameNode}/2026_cdp_workshop/data/grid_measurements/sample-grid-measurements.csv
workDir=${nameNode}/user/<your_user>/oozie/work/landing-check
```

Run it. The decision should take the first branch:

```bash
oozie job -config landing.properties -run
```

```bash
export WF_ID="<job-id-from-the-output>"
oozie job -info "${WF_ID}"
hdfs dfs -ls -R "${OOZIE_HDFS}/work/landing-check"
```

The job is `SUCCEEDED` and the fs action created `archive` and `_CHECKED`.

Run it again, but override `inputFile` on the command line with a file that does not exist. `-D` beats the value in the properties file:

```bash
oozie job -config landing.properties -D inputFile="${NAME_NODE}${WORKSHOP_ROOT}/data/grid_measurements/does-not-exist.csv" -run
```

```bash
export WF_ID="<job-id-from-the-output>"
oozie job -info "${WF_ID}"
```

This time the job ends `KILLED`. Look at the table: which node is `KILLED`, and which message do you see?

**Check question:** The script could also have failed on its own. Why is a `decision` and a named `kill` node with a readable message better for the person on call at night?

---

## 4. Hive — the hive2 action

**Goal:** Run a Hive script from a workflow on a Kerberos-secured cluster.

The `hive2` action runs your script through Beeline against HiveServer2. Copy the example and read the two parts that are new:

```bash
hdfs dfs -cp -f "${OOZIE_LAB}/apps/hive-summary" "${OOZIE_HDFS}/apps/"
hdfs dfs -cat "${OOZIE_HDFS}/apps/hive-summary/workflow.xml"
hdfs dfs -cat "${OOZIE_HDFS}/apps/hive-summary/station_summary.q"
```

- The `credentials` block and `cred="hs2-creds"` on the action. The Oozie server has your identity but the launcher does not have your Kerberos ticket. The credential makes Oozie fetch a **delegation token** for HiveServer2 on your behalf.
- The `param` lines hand values to the script as Hive variables (`${DB}`, `${INPUT_DIR}`, `${RUN_DATE}`).

The script loads one folder as a **partition** of an external table and writes a per-station summary into a second table. The summary uses `INSERT OVERWRITE` on one partition, so running it twice does not duplicate rows.

Create the properties: the input folder is the shared meter sample and the run date matches its data:

```bash
cd "${OOZIE_LOCAL}"
cp common.properties hive.properties
vim hive.properties
```

Add these lines at the end of the file:

```properties
oozie.wf.application.path=${nameNode}/user/<your_user>/oozie/apps/hive-summary
inputDir=${nameNode}/2026_cdp_workshop/data/grid_measurements
runDate=2026-01-15
```

```bash
oozie job -config hive.properties -run
```

```bash
export WF_ID="<job-id-from-the-output>"
oozie job -info "${WF_ID}"
```

When the job is `SUCCEEDED`, query the result in Beeline. Your database has the same name as your user:

```bash
beeline -e "SELECT * FROM ${WORKSHOP_USER}.oozie_station_summary"
```

You should see one row per station for `load_date` `2026-01-15`.

Run the same workflow a second time (same command as above), then count the rows per `load_date`:

```bash
oozie job -config hive.properties -run
beeline -e "SELECT load_date, COUNT(*) FROM ${WORKSHOP_USER}.oozie_station_summary GROUP BY load_date"
```

Wait for the second job to finish before you run the query. The row count must not change.

**Check question:** What would have happened with `INSERT INTO` instead of `INSERT OVERWRITE`? Why does a scheduler make idempotent steps essential?

---

## 5. Spark — the spark3 action

**Goal:** Run a PySpark script from a workflow and see that it creates a second YARN application.

Copy the example. The PySpark script sits in the `lib` folder of the application:

```bash
hdfs dfs -cp -f "${OOZIE_LAB}/apps/spark-weather" "${OOZIE_HDFS}/apps/"
hdfs dfs -ls -R "${OOZIE_HDFS}/apps/spark-weather"
hdfs dfs -cat "${OOZIE_HDFS}/apps/spark-weather/workflow.xml"
```

Compare with the `spark-submit` command of the Spark lab: `master`, `mode`, `jar` (here a `.py` file), `spark-opts` and the `arg` lines map one to one. The `prepare` block deletes the output folder before the job starts.

```bash
cd "${OOZIE_LOCAL}"
cp common.properties spark.properties
vim spark.properties
```

Add these lines at the end of the file:

```properties
oozie.wf.application.path=${nameNode}/user/<your_user>/oozie/apps/spark-weather
runDate=2026-01-15
```

```bash
oozie job -config spark.properties -run
```

```bash
export WF_ID="<job-id-from-the-output>"
oozie job -info "${WF_ID}"
```

While the job runs, list the YARN applications from a second terminal:

```bash
yarn application -list
```

You should see two applications from your run: the Oozie **launcher** (name starts with `oozie:launcher`) and the Spark application `weather-daily`. When the workflow is `SUCCEEDED`, look at the output:

```bash
hdfs dfs -ls "${OOZIE_HDFS}/out/weather_daily/2026-01-15"
```

You should see `_SUCCESS` and one Parquet file.

**Check question:** Which of the two YARN applications does the **Ext ID** in `oozie job -info` point to? Where would you look for the Spark driver log?

---

## 6. A pipeline — fork, join, failure and rerun

**Goal:** Run Hive and Spark in parallel, break one branch on purpose, and repair it with a rerun.

The `meter-daily` application combines the pieces: check the input, then **fork** into the Hive branch and the Spark branch, then **join**. Copy it and find `fork`, `join` and the second `kill` node:

```bash
hdfs dfs -cp -f "${OOZIE_LAB}/apps/meter-daily" "${OOZIE_HDFS}/apps/"
hdfs dfs -cat "${OOZIE_HDFS}/apps/meter-daily/workflow.xml"
```

Create the properties and run it:

```bash
cd "${OOZIE_LOCAL}"
cp common.properties pipeline.properties
vim pipeline.properties
```

Add these lines at the end of the file:

```properties
oozie.wf.application.path=${nameNode}/user/<your_user>/oozie/apps/meter-daily
inputDir=${nameNode}/2026_cdp_workshop/data/grid_measurements
runDate=2026-01-15
```

```bash
oozie job -config pipeline.properties -run
```

```bash
export WF_ID="<job-id-from-the-output>"
oozie job -info "${WF_ID}"
```

Both branches (`summary` and `weather-daily`) appear in the table with overlapping start times. The workflow succeeds only when both reach the join.

Now break the Spark branch. Run the same application with a wrong weather folder:

```bash
oozie job -config pipeline.properties -D weatherDir="${NAME_NODE}${WORKSHOP_ROOT}/data/operator_weather_typo" -run
```

```bash
export WF_ID="<job-id-from-the-output>"
oozie job -info "${WF_ID}"
```

The job ends `KILLED`. Look at the **Status** and **Err Code** of each action and the error message of the kill node. Find the reason in the log of the failing launcher or Spark application, like you did in section 2.

You do not need to start from the beginning. A **rerun** re-executes only the nodes that did not succeed. `pipeline.properties` has the correct `weatherDir`, so you pass it without the override:

```bash
oozie job -rerun "${WF_ID}" -config pipeline.properties -D oozie.wf.rerun.failnodes=true
```

```bash
oozie job -info "${WF_ID}"
```

Repeat `-info` until the job is `SUCCEEDED`. It keeps its job ID, the `Run` counter in the job header went from 0 to 1, and a node that had already succeeded was not executed again.

**Check question:** Why does a rerun of a workflow that loads data need every step to be idempotent?

---

## 7. Coordinator — start a workflow on a schedule

**Goal:** Run the `landing-check` workflow every five minutes and understand **nominal time**.

A **coordinator** is a second Oozie application type. It does not do work; it creates workflow runs ("actions") for time slots. Copy the coordinator definition and read it:

```bash
hdfs dfs -cp -f "${OOZIE_LAB}/coord/landing-check-coord" "${OOZIE_HDFS}/coord/"
hdfs dfs -cat "${OOZIE_HDFS}/coord/landing-check-coord/coordinator.xml"
```

Find `frequency`, `start`, `end`, the `controls` and the `workflow` with its `app-path`. The workflow gets a different `workDir` per run, built from the **nominal time** — the time slot the action is for.

Choose a window that starts ten minutes in the past and ends ten minutes from now. `date` gives the UTC times in the format Oozie expects:

```bash
export START=$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%MZ)
export END=$(date -u -d '10 minutes' +%Y-%m-%dT%H:%MZ)
echo "${START} ${END}"
```

```bash
cd "${OOZIE_LOCAL}"
cp common.properties landing-coord.properties
vim landing-coord.properties
```

Add these lines at the end of the file (replace `<start>` and `<end>` with the values printed by `echo` above):

```properties
oozie.coord.application.path=${nameNode}/user/<your_user>/oozie/coord/landing-check-coord
wfAppPath=${nameNode}/user/<your_user>/oozie/apps/landing-check
start=<start>
end=<end>
inputFile=${nameNode}/2026_cdp_workshop/data/grid_measurements/sample-grid-measurements.csv
workRoot=${nameNode}/user/<your_user>/oozie/work/landing-check-coord
```

A **dry run** shows what the coordinator would create without starting anything:

```bash
oozie job -dryrun -config landing-coord.properties
```

Look for the nominal times in the output: one every five minutes between `start` and `end`. Now start it. The job ID ends with `-C` (coordinator):

```bash
oozie job -config landing-coord.properties -run
```

```bash
export COORD_ID="<job-id-from-the-output>"
oozie job -info "${COORD_ID}"
```

The table now lists coordinator **actions**:

- **ID** — `<coordinator-id>@<number>`
- **Status** — `WAITING`, `READY`, `RUNNING`, `SUCCEEDED`, …
- **Ext ID** — the workflow job started for this slot
- **Created** and **Nominal Time** — when Oozie created the action, and which slot it represents

The first actions have a nominal time in the past: Oozie **catches up** and runs them right away (one at a time, because of `concurrency` 1). The later slots wait for their time.

Continue with section 8 while the coordinator works. Come back after about ten minutes:

```bash
oozie job -info "${COORD_ID}"
hdfs dfs -ls "${OOZIE_HDFS}/work/landing-check-coord"
```

The coordinator ends `SUCCEEDED` after the last action. In the work folder you should see one sub-folder per nominal time, named like `20261101_1805`.

**Check question:** The folder names show the nominal time, not the time the workflow actually ran. Why is that the right choice for a daily load that has to be rerun after a failure?

---

## 8. Coordinator — start a workflow when data arrives

**Goal:** Let a coordinator wait for a folder with a done-flag and start the pipeline only then.

Time is not always the right trigger. Often the data source delivers "when it is ready". A coordinator can wait for a **dataset** instance. Copy this second coordinator and read it:

```bash
hdfs dfs -cp -f "${OOZIE_LAB}/coord/meter-daily-coord" "${OOZIE_HDFS}/coord/"
hdfs dfs -cat "${OOZIE_HDFS}/coord/meter-daily-coord/coordinator.xml"
```

Find the `dataset` with its `uri-template` (one folder per day) and `done-flag`, the `input-events` that name the instance `coord:current(0)` (= the folder of the nominal day), and how `coord:dataIn('input')` hands that folder to the workflow as `inputDir`.

Define the day. The coordinator runs for today in UTC and has one action:

```bash
export TODAY=$(date -u +%Y%m%d)
export DAILY_START=$(date -u +%Y-%m-%dT00:00Z)
export DAILY_END=$(date -u -d tomorrow +%Y-%m-%dT00:00Z)
```

```bash
cd "${OOZIE_LOCAL}"
cp common.properties daily-coord.properties
vim daily-coord.properties
```

Add these lines at the end of the file (replace `<daily-start>` and `<daily-end>` with the values of `DAILY_START` and `DAILY_END`: run `echo "${DAILY_START} ${DAILY_END}"`):

```properties
oozie.coord.application.path=${nameNode}/user/<your_user>/oozie/coord/meter-daily-coord
wfAppPath=${nameNode}/user/<your_user>/oozie/apps/meter-daily
start=<daily-start>
end=<daily-end>
landingRoot=${nameNode}/user/<your_user>/oozie/landing
```

Start the coordinator. The landing folder for today does not exist yet:

```bash
oozie job -config daily-coord.properties -run
```

```bash
export DAILY_ID="<job-id-from-the-output>"
oozie job -info "${DAILY_ID}"
```

After a minute the single action is `WAITING`. Ask for the details of that action to see what it waits for:

```bash
oozie job -info "${DAILY_ID}@1"
```

Find **Missing Dependencies**: the path of the `_SUCCESS` file for today.

Now act as the data source. First deliver the data **without** the flag:

```bash
hdfs dfs -mkdir -p "${OOZIE_HDFS}/landing/${TODAY}"
hdfs dfs -cp -f "${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv" "${OOZIE_HDFS}/landing/${TODAY}/"
oozie job -info "${DAILY_ID}@1"
```

The action stays `WAITING`: the file is there, but nobody said it is complete. Now write the done-flag, the same empty file a Spark or MapReduce job writes at the end:

```bash
hdfs dfs -touchz "${OOZIE_HDFS}/landing/${TODAY}/_SUCCESS"
```

Oozie checks the input about once a minute. Repeat until the action is `RUNNING` and a workflow ID appears in **Ext ID**, then follow that workflow to `SUCCEEDED`:

```bash
oozie job -info "${DAILY_ID}"
oozie job -info "<workflow-id-from-the-ext-id-column>"
```

The pipeline ran for today's partition. Check both outputs:

```bash
beeline -e "SELECT load_date, COUNT(*) FROM ${WORKSHOP_USER}.oozie_station_summary GROUP BY load_date"
hdfs dfs -ls "${OOZIE_HDFS}/out/weather_daily"
```

You should see a second `load_date` and a second output folder, named like today's date.

**Check question:** What is the difference between waiting for a time and waiting for a `_SUCCESS` file when the source system delivers late? What does `timeout` in the coordinator do about it?

---

## 9. Monitor and clean up

**Goal:** Find your jobs, control a running coordinator, and leave nothing running.

List your recent workflows and your coordinators:

```bash
oozie jobs -jobtype wf -filter "user=${WORKSHOP_USER}" -len 20
oozie jobs -jobtype coordinator -filter "user=${WORKSHOP_USER}" -len 10
```

The daily coordinator is still `RUNNING`: its end time is tomorrow. Pause it, look at the state, and resume it:

```bash
oozie job -suspend "${DAILY_ID}"
oozie job -info "${DAILY_ID}"
oozie job -resume "${DAILY_ID}"
```

Never leave test coordinators running. Kill it:

```bash
oozie job -kill "${DAILY_ID}"
oozie job -info "${DAILY_ID}"
```

The status is `KILLED`. Check that the time-based coordinator from section 7 has ended or kill it too.

**Optional — look at it in Hue.** Open **Jobs** in Hue (Job Browser) and switch to the **Workflows** and **Schedules** tabs. Open `meter-daily-wf`: Hue draws the graph with the fork and the join, and links to the logs of each action.

---

## Stretch (optional)

- Add an **email** action to the `error` path of `meter-daily` (needs an SMTP server configured in Oozie; ask your instructor).
- Start the time-based coordinator with `<execution>LAST_ONLY</execution>` and compare what happens to the catch-up slots.
- Rerun a single coordinator action: `oozie job -rerun "${COORD_ID}" -action 1`.
- Read the schema of the `bundle` application type: one bundle starts several coordinators together (for example one per data source).
- Change the end time of a running coordinator: `oozie job -change "${COORD_ID}" -value endtime=<time>`.

---

## Self-check

From the repo on the edge node (with `OOZIE_URL` exported as above):

```bash
./11-advanced-oozie/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
