# YARN hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path.

Set your Kerberos identity and paths once for the whole lab. `WORKSHOP_USER` is the short name you use with `kinit` (same account as on the edge node). `YARN_LAB` points at shared module files on HDFS (the input text all jobs read, and the Spark script).

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export YARN_LAB="${WORKSHOP_ROOT}/03-yarn"
```

YARN does not store data — HDFS does. YARN decides which **applications** (MapReduce, Tez, Spark) get **containers** (CPU and memory) on which worker nodes. Every job in this lab reads from and writes to HDFS.

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

**Goal:** Run a classic MapReduce job: count how often each word occurs in a text.

Word count needs running text — in a CSV every row would be a single "word". All jobs in this lab therefore read the same text: the first chapter of Franz Kafka's *Die Verwandlung* (public domain), shared under `${YARN_LAB}/input`. Look at the file first:

```bash
hdfs dfs -ls -h "${YARN_LAB}/input"
hdfs dfs -cat "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" | head -5
```

The Hadoop examples JAR ships with every cluster. Submit the `wordcount` example; the output directory in your HDFS home must not exist yet:

```bash
hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  wordcount \
  "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" \
  "/user/${WORKSHOP_USER}/wordcount-mr"
```

The JAR path above is the CDP parcel default — ask your instructor if it differs on your cluster. While the job runs, the console prints the YARN application ID (`application_…`) and the map/reduce progress.

List the output directory. Each line of the result file is a word, a tab, and its count. Show the ten most frequent words by sorting on the count (second column, descending):

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/wordcount-mr"
hdfs dfs -cat "/user/${WORKSHOP_USER}/wordcount-mr/part-r-00000" | sort -k2 -nr | head -10
```

You should see a `_SUCCESS` marker and at least one `part-r-*` file, and common German words such as `der`, `die`, and `und` at the top.

**Check question:** `Gregor` and `Gregor,` appear as two different words. Why? What does that tell you about the job's definition of a "word"?

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

Hive runs on Tez in the Hive module. Here you call Tez directly through its examples JAR. The `wordcount` example does the same work as the MapReduce one: it reads the same text and counts words. Only the engine differs.

A Tez client needs the Tez configuration (it tells Tez where the Tez libraries for the containers are) and the Tez jars on its classpath. Set them once in this terminal:

```bash
export HADOOP_CLASSPATH="/opt/cloudera/parcels/CDH/lib/tez/conf:/opt/cloudera/parcels/CDH/lib/tez/bin/*:/opt/cloudera/parcels/CDH/lib/tez/*"
```

Submit the job. The JAR file name contains the Tez version of your cluster, so the `*` in the path stands for it:

```bash
yarn jar /opt/cloudera/parcels/CDH/lib/tez/bin/tez-examples-*.jar \
  wordcount \
  "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" \
  "/user/${WORKSHOP_USER}/wordcount-tez"
```

If the shell reports more than one match or `No such file`, ask your instructor for the exact JAR path. Note the application ID in the console output, then check the output and list Tez applications. Look at the application type column:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}/wordcount-tez"
yarn application -list -appStates FINISHED -appTypes TEZ
```

You should see `_SUCCESS` in the output directory and your application in the Tez list.

---

## 7. Compare — MapReduce vs Tez

**Goal:** Run the same word count on **many small files** with both engines and see how many containers each one needs.

On the single file in sections 3 and 6 the two engines do about the same work, and a cold Tez job is often not faster: Tez first has to start its ApplicationMaster and make the Tez libraries (about 1 GB) available on the worker nodes. Tez pays off when there is a lot to do — for example many small files, which is also the typical situation in a data lake.

The shared folder `${YARN_LAB}/input-many` holds the same text, cut into about 100 small files. Look at it:

```bash
hdfs dfs -count "${YARN_LAB}/input-many"
hdfs dfs -ls "${YARN_LAB}/input-many" | head -5
```

Run word count with MapReduce and with Tez on that **folder**. Use the same terminal as in section 6 for the Tez command, and note the `real` time that `time` prints:

```bash
hdfs dfs -rm -r -f -skipTrash "/user/${WORKSHOP_USER}/wordcount-mr-many" "/user/${WORKSHOP_USER}/wordcount-tez-many"
time hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar \
  wordcount "${YARN_LAB}/input-many" "/user/${WORKSHOP_USER}/wordcount-mr-many"
time yarn jar /opt/cloudera/parcels/CDH/lib/tez/bin/tez-examples-*.jar \
  wordcount "${YARN_LAB}/input-many" "/user/${WORKSHOP_USER}/wordcount-tez-many"
```

Run the Tez job a **second time**. The first run had the one-time cost of distributing the Tez libraries to the nodes; the second one shows what Tez costs when it is warm. Remove its output first:

```bash
hdfs dfs -rm -r -skipTrash "/user/${WORKSHOP_USER}/wordcount-tez-many"
time yarn jar /opt/cloudera/parcels/CDH/lib/tez/bin/tez-examples-*.jar \
  wordcount "${YARN_LAB}/input-many" "/user/${WORKSHOP_USER}/wordcount-tez-many"
```

Now count the containers of each application. List the applications, then list the containers of the MapReduce run and of the last Tez run. The first container of every application (`…_000001`) is its ApplicationMaster:

```bash
yarn application -list -appStates FINISHED -appTypes MAPREDUCE,TEZ
yarn logs -applicationId "<application-id>" -show_application_log_info
```

Optionally also read the aggregate resource allocation with `yarn application -status "<application-id>"`. Fill in your table:

| | MapReduce | Tez (first run) | Tez (second run) |
|---|-----------|-----------------|------------------|
| Elapsed time | `real` of `time` | `real` of `time` | `real` of `time` |
| Containers | number of container IDs in the `yarn logs` listing | same | same |

**Check question:** Why does MapReduce need so many containers for this input, and what does Tez do instead with the many small files? Why was the first Tez run slower than the second? What does this mean for a data lake that receives thousands of small files per day — and which HDFS concept from the first lab is involved?

---

## 8. Spark on YARN — line count

**Goal:** Run a PySpark job in cluster mode on YARN and count the lines of the same text.

In cluster mode the Spark driver runs inside a YARN container, so your terminal only shows submission progress — the job output lives in the YARN logs. The script `spark_linecount.py` is shared on HDFS. `spark-submit` treats a path **without a scheme** as a **local** file on the machine you submit from. You can submit the script from either place — try both.

**8a. Script on HDFS.** Use an `hdfs://` URI. YARN fetches the script directly from HDFS, so it works from any node:

```bash
spark-submit --master yarn --deploy-mode cluster \
  --name "linecount-hdfs-${WORKSHOP_USER}" \
  "hdfs://${YARN_LAB}/assets/spark_linecount.py" \
  "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" \
  "/user/${WORKSHOP_USER}/linecount-spark"
```

**8b. Script on the local disk.** Copy the script from HDFS to your current node first, then submit the local path. `spark-submit` uploads it to the `.sparkStaging` directory in HDFS (watch for the `Uploading resource file:...` line in the output) and YARN ships it to the containers:

```bash
hdfs dfs -get "${YARN_LAB}/assets/spark_linecount.py" /tmp/spark_linecount.py
ls -l /tmp/spark_linecount.py

spark-submit --master yarn --deploy-mode cluster \
  --name "linecount-local-${WORKSHOP_USER}" \
  /tmp/spark_linecount.py \
  "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" \
  "/user/${WORKSHOP_USER}/linecount-spark-local"
```

Without the first step, the same command fails with `FileNotFoundException: File file:/tmp/spark_linecount.py does not exist` — the local path only exists on the node where you created it.

Read the results from HDFS — both runs should print the same value:

```bash
hdfs dfs -cat "/user/${WORKSHOP_USER}/linecount-spark/part-*"
hdfs dfs -cat "/user/${WORKSHOP_USER}/linecount-spark-local/part-*"
```

You should see one line `line_count=…`. Compare it with the line count of the file itself:

```bash
hdfs dfs -cat "${YARN_LAB}/input/die-verwandlung-kapitel-1.txt" | wc -l
```

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

**Check question:** All three jobs read the same text file in `${YARN_LAB}/input`. What would break or get duplicated if Hive, Spark, and MapReduce ran on separate clusters instead of sharing YARN and HDFS?

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

- Tez multi-stage: run `orderedwordcount` (same JAR and `HADOOP_CLASSPATH` as in section 6, same arguments, new output path) and compare its vertices with the single-stage `wordcount` in the ResourceManager UI.  
- ResourceManager UI: open one finished application and find its containers and the node each ran on.  
- Hue: browse `/user/${WORKSHOP_USER}/wordcount-mr` in File Browser.

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket and HDFS home):

```bash
./03-basics-yarn/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
