# YARN hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need `sample-landisgyr-data.csv` in your HDFS home from the [HDFS lab](../../01-basics-hdfs/lab/lab.md).

Set your Kerberos identity and paths once for the whole lab. `WORKSHOP_USER` is the short name you use with `kinit` (same account as on the edge node). `YARN_LAB` points at shared module files on HDFS (the Spark script).

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export YARN_LAB="${WORKSHOP_ROOT}/02-yarn"
```

YARN does not store data — HDFS does. YARN decides which **applications** (MapReduce, Tez, Spark) get **containers** (CPU and memory) on which worker nodes. Every job in this lab reads and writes the HDFS paths you already know.

---

## 1. Orient — cluster and nodes

**Goal:** See that the ResourceManager knows its NodeManagers before you submit any work.

List all nodes with their state, running containers, and capacity:

```bash
yarn node -list -all
```

You should see several nodes in state `RUNNING`.

Optional: open the **ResourceManager UI** (URL from your workshop handout) and compare its node list with the CLI output.

**Check question:** What happens to a new application when all NodeManagers are full? Why does that matter for a daily grid-data batch load?

---

## 2. Queues and applications

**Goal:** Find out which queue your jobs run in and what is already running on the cluster.

Every application is submitted to a queue, and queues share cluster capacity. Show the status of the default queue (capacity, current usage, state):

```bash
yarn queue -status root.default
```

List the applications the ResourceManager currently knows about:

```bash
yarn application -list
```

If your instructor assigned a workshop queue, run `yarn queue -status` again with that queue name.

**Check question:** Why would a cluster run grid analytics and ad-hoc exploration in separate queues?

---

## 3. MapReduce on YARN — word count

**Goal:** Run a classic MapReduce job on the smart-meter CSV in your HDFS home.

The Hadoop examples JAR ships with every cluster. Submit the `wordcount` example against the file you copied in the HDFS lab; the output directory must not exist yet:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  wordcount \
  "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv" \
  "/user/${WORKSHOP_USER}/wordcount-mr"
```

The JAR path above is the CDP parcel default — ask your instructor if it differs on your cluster. While the job runs, the console prints the YARN application ID (`application_…`) and the map/reduce progress.

List the output directory and look at the first result lines:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/wordcount-mr"
hdfs dfs -cat "/user/${WORKSHOP_USER}/wordcount-mr/part-r-00000" | head -20
```

You should see a `_SUCCESS` marker and at least one `part-r-*` file.

---

## 4. Application status and logs

**Goal:** Connect the job you just ran to its YARN application ID, final status, and container logs.

List finished MapReduce applications and find the one you submitted (check the user column):

```bash
yarn application -list -appStates FINISHED -appTypes MAPREDUCE
```

Show its state, final status, queue, and tracking URL, then read the aggregated container logs. Use the `application_…` ID from the listing:

```bash
yarn application -status "<application-id>"
yarn logs -applicationId "<application-id>" | tail -50
```

The logs can take a minute to appear after the job finishes. Keep the application ID — you need it again in section 7.

**Check question:** A job fails during the map phase. Where do you look first — the input path in HDFS, the YARN application status, or the container logs? In which order?

Optional: open **Hue → Job Browser** and find the same application.

---

## 5. The ApplicationMaster — who runs your job

**Goal:** Watch an application while it runs and find its ApplicationMaster, the first container of every YARN application.

The ResourceManager only hands out containers. For every application it first starts one container that runs the application's own coordinator: the **ApplicationMaster (AM)**. The AM asks the ResourceManager for more containers, starts the tasks in them, and tracks their progress. MapReduce, Tez, and Spark each bring their own AM.

You need two terminals on the edge node (same user, valid ticket). In **terminal 1**, start a MapReduce job that runs long enough to watch. The two numbers are the count of map tasks and the samples per task — raise the second number if the job finishes before you are done observing:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  pi 10 50000000
```

In **terminal 2**, while the job runs, find your application and its attempt. The attempt listing shows the AM container ID and the node it runs on:

```bash
yarn application -list -appStates RUNNING
yarn applicationattempt -list "<application-id>"
```

List the containers of that attempt. Run the command several times while the job progresses:

```bash
yarn container -list "<application-attempt-id>"
```

You should see the AM container (`…_000001`) plus map containers that appear and disappear as tasks start and finish. Container listings only work while the application is running.

Open the **tracking URL** from `yarn application -status "<application-id>"` in a browser or with `curl -L` — it is the AM's own web UI, reached through the ResourceManager proxy.

When the job has finished, read the AM's log. It is the container you identified above:

```bash
yarn logs -applicationId "<application-id>" -containerId "<am-container-id>" -log_files syslog | less
```

Search the log for lines about containers being requested, assigned, and launched. This is the AM negotiating with the ResourceManager and the NodeManagers.

**Check question:** What does the AM do that the ResourceManager does not? What happens to the running map tasks if the AM container dies?

---

## 6. Tez on YARN — the same word count

**Goal:** Run the **same job on the same file** with Tez, so you can compare it with section 3.

Hive runs on Tez in the next module. Here you call Tez directly through its examples JAR. The `wordcount` example does the same work as the MapReduce one: it reads your smart-meter CSV and counts words. Only the engine differs:

```bash
yarn jar /opt/cloudera/parcels/CDH/lib/tez/tez-examples.jar \
  wordcount \
  "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv" \
  "/user/${WORKSHOP_USER}/wordcount-tez"
```

Again the JAR path is the CDP parcel default — ask your instructor if it differs. Note the application ID in the console output, then check the output and list Tez applications. Look at the application type column:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/wordcount-tez"
yarn application -list -appStates FINISHED -appTypes TEZ
```

You should see `_SUCCESS` in the output directory and your application in the Tez list.

---

## 7. Compare — MapReduce vs Tez

**Goal:** Put the two runs side by side and find out how they differ in time, resources, and containers.

You now have two finished applications that did the same work. Show the status of each (use the `application_…` IDs from sections 4 and 6) and compare start time, finish time, and the **aggregate resource allocation** (memory and vcore seconds the application held):

```bash
yarn application -status "<mapreduce-application-id>"
yarn application -status "<tez-application-id>"
```

Now list the containers each application used. The first container of every application (`…_000001`) is its ApplicationMaster:

```bash
yarn logs -applicationId "<mapreduce-application-id>" -show_application_log_info
yarn logs -applicationId "<tez-application-id>" -show_application_log_info
```

Collect your numbers:

| | MapReduce | Tez |
|---|-----------|-----|
| Elapsed time | | |
| Containers (incl. ApplicationMaster) | | |
| Aggregate resource allocation | | |

Optional: open both applications in the **ResourceManager UI** (follow the tracking URL from `-status`). For MapReduce you see separate map and reduce tasks; for Tez you see one DAG with vertices. Compare the two views.

**Check question:** Which engine finished faster on this small file, and which used fewer containers? Which of the differences you measured would grow with a multi-stage job on a large dataset — and why does that matter for Hive?

---

## 8. Spark on YARN — line count

**Goal:** Run a PySpark job in cluster mode on YARN and count the lines of your smart-meter CSV.

In cluster mode the Spark driver runs inside a YARN container, so your terminal only shows submission progress — the job output lives in the YARN logs. The script `spark_linecount.py` is shared on HDFS:

```bash
spark-submit --master yarn --deploy-mode cluster \
  --name "linecount-${WORKSHOP_USER}" \
  "${YARN_LAB}/assets/spark_linecount.py" \
  "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv" \
  "/user/${WORKSHOP_USER}/linecount-spark"
```

Read the result from HDFS:

```bash
hdfs dfs -cat "/user/${WORKSHOP_USER}/linecount-spark/part-*"
```

You should see one line `line_count=…`. The number includes the comment line you appended in the HDFS lab.

Find the application and read its driver log, as in section 4:

```bash
yarn application -list -appStates FINISHED -appTypes SPARK
yarn logs -applicationId "<application-id>" | tail -50
```

---

## 9. Relate — one platform, three engines

**Goal:** Place the three jobs on the same map: same HDFS, same ResourceManager, different engines.

Compare all your finished applications side by side (type, queue, run time):

```bash
yarn application -list -appStates FINISHED -appTypes MAPREDUCE,TEZ,SPARK
```

**Check question:** All three jobs read the same CSV in your home. What would break or get duplicated if Hive, Spark, and MapReduce ran on separate clusters instead of sharing YARN and HDFS?

---

## 10. Optional — ask for more than fits

**Goal:** Raise the memory a MapReduce job requests until YARN can no longer start it, and learn to tell the different "stuck" situations apart.

Every container request carries a memory size. YARN only grants it if the request fits the scheduler limits, your queue, and a node with free memory. Start by looking at what your cluster can offer — note the memory capacity per node and the queue capacity and maximum capacity:

```bash
yarn node -list -all
yarn node -status "<node-id>"
yarn queue -status root.default
```

First a request that still fits. Run `pi` with larger map and AM containers (`-D` settings go right after the program name). Then compare **aggregate resource allocation** in `yarn application -status` with your `pi` run from section 5:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  pi \
  -Dmapreduce.map.memory.mb=4096 \
  -Dyarn.app.mapreduce.am.resource.mb=2048 \
  2 100000
```

Now make the **map containers** too large. Multiply the value by 4 each run (16384, 65536, 262144, …) until the job no longer runs normally. Watch from a second terminal with `yarn application -list`:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  pi \
  -Dmapreduce.map.memory.mb=<memory-mb> \
  2 100000
```

Depending on your cluster limits you see one of three outcomes: the job runs, YARN rejects or kills it with a message about the maximum allowed allocation, or the job keeps running at 0% because the map tasks wait forever. In the last case look at `yarn application -status "<application-id>"` (progress and diagnostics), find the AM container with the commands from section 5, then stop the job:

```bash
yarn application -kill "<application-id>"
```

Finally make the **AM container** too large and keep the map memory at its default:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  pi \
  -Dyarn.app.mapreduce.am.resource.mb=<memory-mb> \
  2 100000
```

This time the application stays in `ACCEPTED`: no AM was ever started, so no task exists at all. Read the diagnostics in `yarn application -status`, and compare the **Scheduler** page of the ResourceManager UI. Kill the application when you have seen enough.

**Check question:** In which state is the application when the map containers are too large, and in which state when the AM container is too large? How do you tell the two apart from the CLI? Why is a request that does not fit more dangerous on a shared grid-analytics queue than a slow job?

---

## Stretch (optional)

Watch containers and queues live while a colleague's job runs (quit with `q`):

```bash
yarn top
```

- Tez multi-stage: run `orderedwordcount` (same JAR, same arguments, new output path) and compare its vertices with the single-stage `wordcount` in the ResourceManager UI.  
- ResourceManager UI: open one finished application and find its containers and the node each ran on.  
- Hue: browse `/user/${WORKSHOP_USER}/wordcount-mr` in File Browser.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket and HDFS home):

```bash
./02-basics-yarn/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
