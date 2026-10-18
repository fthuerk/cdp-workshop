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

The logs can take a minute to appear after the job finishes. Keep the application ID — you need it again in section 6.

**Check question:** A job fails during the map phase. Where do you look first — the input path in HDFS, the YARN application status, or the container logs? In which order?

Optional: open **Hue → Job Browser** and find the same application.

---

## 5. Tez on YARN — the same word count

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

## 6. Compare — MapReduce vs Tez

**Goal:** Put the two runs side by side and find out how they differ in time, resources, and containers.

You now have two finished applications that did the same work. Show the status of each (use the `application_…` IDs from sections 4 and 5) and compare start time, finish time, and the **aggregate resource allocation** (memory and vcore seconds the application held):

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

## 7. Spark on YARN — line count

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

## 8. Relate — one platform, three engines

**Goal:** Place the three jobs on the same map: same HDFS, same ResourceManager, different engines.

Compare all your finished applications side by side (type, queue, run time):

```bash
yarn application -list -appStates FINISHED -appTypes MAPREDUCE,TEZ,SPARK
```

**Check question:** All three jobs read the same CSV in your home. What would break or get duplicated if Hive, Spark, and MapReduce ran on separate clusters instead of sharing YARN and HDFS?

---

## Stretch (optional)

Watch containers and queues live while a colleague's job runs (quit with `q`):

```bash
yarn top
```

Estimate pi with MapReduce — no input data and no HDFS output, just containers doing work:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 2 100000
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
