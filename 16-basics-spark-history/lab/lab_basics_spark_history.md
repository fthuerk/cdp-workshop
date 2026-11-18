# Spark History Server hands-on lab

Run sections in order. You start **one** Spark application, keep it open, and run nine small steps in it. After every step you switch to the Spark History Server, find what that step left behind, and read the numbers. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path.

You need two windows side by side: the place where you type Spark code (a terminal with `pyspark3`, or a Jupyter notebook) and a browser tab with the History Server.

| Part | Sections | What you do |
|------|----------|-------------|
| **A. Orient** | 0 | Start the application, open the History Server, prepare the labels that link the UI to your code |
| **B. Steps** | 1–9 | One step per section; each ends with a look into the UI |
| **C. Wrap-up** | 10 | End the application and read it as a *completed* application |

**Two ways to run the code.** Every Python block in this lab is the same in both ways:

- **Edge node:** type or paste the blocks into `pyspark3` (the `>>>` prompt).
- **Laptop notebook:** run them as cells of [notebooks/spark_history_sparkmagic.ipynb](notebooks/spark_history_sparkmagic.ipynb) through Livy and `sparkmagic`. Set up Jupyter as in [module 09, section 6](../../09-basics-livy/lab/lab_basics_livy.md). The notebook holds the same code with a short version of the UI hints; this document explains the UI in full.

The only block that differs is the one that sets paths (section 0.1). The History Server looks the same for both.

**Pasting into `pyspark3`:** after you paste a function (`def ...`) or a loop (`for ...`), press Enter once more so the shell closes it. Inside brackets `( )` the lab never leaves empty lines.

**Screenshots:** every place marked `SCREENSHOT` shows which picture belongs there (file name in [images/](images/)). Your own screen should look similar.

---

# Part A — Orient

## 0. Start the application and open the History Server

**Goal:** Have a running Spark application, find it in the History Server, and label your code so every UI row can be traced back to it.

### 0.1 Start the application

Edge node route: set your Kerberos identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`.

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
```

The `kinit` asks for your password, so it has its own block. Then set the rest:

```bash
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export WORKSHOP_HOME="/user/${WORKSHOP_USER}"   # your HDFS home; the lab writes one folder below it
export HADOOP_CONF_DIR=/etc/hadoop/conf   # must be set before pyspark3, otherwise the shell prints many warnings

# the only input file of this lab
export METER_CSV="${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv"
```

Start the shell. The `--name` is what you will search for in the History Server:

```bash
pyspark3 --name "spark-history-${WORKSHOP_USER}"
```

Notebook route: open the notebook, run the connection cells at the top (they create a Livy session named `<you>-spark-history-<time>`), and continue below.

Wait for the `>>>` prompt (or the idle session), then read the paths into Python. Use the first block in `pyspark3`, the second one in the notebook (the cluster session does not see your shell variables).

**Edge node (`pyspark3`):**

```python
# paths and user come from the exports of the terminal that started pyspark3
import os
workshop_user = os.environ["WORKSHOP_USER"]
workshop_home = os.environ["WORKSHOP_HOME"]
meter_csv     = os.environ["METER_CSV"]
out_path      = f"{workshop_home}/spark-history-out"
print(workshop_user, out_path)
```

**Notebook (Livy session):**

```python
import getpass

workshop_root = "/2026_cdp_workshop"          # change only if your handout says otherwise
workshop_user = getpass.getuser()             # the session runs as you
workshop_home = "/user/" + workshop_user
meter_csv     = workshop_root + "/data/grid_measurements/sample-grid-measurements.csv"
out_path      = workshop_home + "/spark-history-out"
print(workshop_user, out_path)
```

Print the identity of your application. You will compare these values with the History Server in a moment:

```python
sc = spark.sparkContext
print("application id  :", sc.applicationId)
print("application name:", sc.appName)
print("live UI         :", sc.uiWebUrl)
print("event log dir   :", sc.getConf().get("spark.eventLog.dir", "(not set)"))
```

The **application id** (`application_<number>_<number>`) is the key for everything that follows: it is the YARN application, the folder name of the event log, and the row in the History Server. The **event log dir** is where Spark writes a JSON line for every event (job started, task finished, ...) while your application runs.

Also print four settings that change what you will see in the UI. Note the values, you will find them again in the **Environment** tab in section 10:

```python
# a core setting: not set explicitly, so Spark's default (4 attempts per task) applies
print("spark.task.maxFailures =", spark.sparkContext.getConf().get("spark.task.maxFailures", "4 (Spark default)"))

# SQL settings always have a value, the default if nobody changed them
for key in ["spark.sql.adaptive.enabled", "spark.sql.shuffle.partitions",
            "spark.sql.autoBroadcastJoinThreshold"]:
    print(key, "=", spark.conf.get(key))
```

### 0.2 Open the History Server and find your application

Open the **Spark History Server** (URL from your handout, or Cloudera Manager → Spark 3 → *Spark3 History Server Web UI*). The start page lists applications.

> **SCREENSHOT** `images/01-history-app-list.png`: the application list, filtered to your user name, with the column headers visible (App ID, App Name, Started, Completed, Duration, Spark User, Last Updated, Event Log).
<!-- ![Application list](images/01-history-app-list.png) -->

Your application is **not** in the default list: it is still running, and the default list shows only completed applications. Click **Show incomplete applications** at the bottom, and search for your user name or `spark-history`.

> **SCREENSHOT** `images/02-history-show-incomplete.png`: the link *Show incomplete applications* and your application in the incomplete list (Completed column empty).
<!-- ![Show incomplete applications](images/02-history-show-incomplete.png) -->

Read the columns:

- **App ID / App Name:** the application id you printed, and the name you passed with `--name` (notebook: the Livy session name).
- **Started / Completed / Duration:** `Completed` stays empty while the application runs.
- **Spark User:** you. Filter by it when the list is long.
- **Event Log:** a download link of the raw JSON file. The History Server **rebuilds every page from this file**; it does not talk to your application.

Click the **App ID** to open the application. The first page is the **Jobs** tab, still empty: you have not run an action yet.

> **SCREENSHOT** `images/03-app-empty-jobs-tab.png`: the Jobs tab of your application before any job, with the tab bar (Jobs, Stages, Storage, Environment, Executors, SQL / DataFrame) visible.
<!-- ![Empty Jobs tab](images/03-app-empty-jobs-tab.png) -->

**If your application is missing:** wait about 10 seconds and reload (the History Server rescans the event log directory periodically), check that **Show incomplete applications** is on, and compare the id with the one you printed. Ask your instructor if it is still missing after a minute.

**The live UI shows the same pages.** While the application runs, the ResourceManager (YARN UI) links to the Spark UI itself (`application_...` → *ApplicationMaster*). The History Server pages are identical; it just keeps them after the application has ended. In this lab you stay in the History Server.

### 0.3 Label your code so you can find it in the UI

Spark names jobs after the place in the Spark source that started them, for example `count at NativeMethodAccessorImpl.java:0`. In PySpark that never points at *your* line. So the lab gives every step a **label**. Two small functions do it. `step()` puts a label on every job that follows; `jobs()` prints the job ids a step has started, so you can look for exactly those numbers in the UI.

```python
from pyspark.sql import functions as F

# the ledger remembers what each step was about
ledger = {}
```

```python
def step(key, text):
    # every job started after this call is labelled "<key>: <text>" in the UI
    spark.sparkContext.setJobGroup(key, f"{key}: {text}")
    ledger[key] = text
```

```python
def jobs(key):
    # the job ids this step has started so far: compare them with the Jobs tab
    ids = sorted(spark.sparkContext.statusTracker().getJobIdsForGroup(key))
    print(f"{key} - {ledger[key]}: job ids {ids}")
```

You will now see three things everywhere in the UI: the label in the **Description** column (`S1: read csv ...`), the **job ids** your code printed, and the **stage and task counts** that you can predict from your code (for example `getNumPartitions()`).

### 0.4 A map of the UI

Keep this in mind while you work. Each tab answers one question:

- **Jobs:** one row per **job**, usually one per **action** you ran (`count`, `show`, `collect`, `write`, ...). *Which of my actions was slow? Which one failed?*
- **Stages:** one row per **stage**, the parts a job is cut into at every shuffle. *Where does the time go? Which stage moves the most data?*
- **Storage:** every cached DataFrame. *What is cached, how big, how much of it?*
- **Environment:** every configuration value of this application. *Which settings explain what I see?*
- **Executors:** the driver and the executor containers. *Who did the work, how much GC, which logs?*
- **SQL / DataFrame:** one row per DataFrame or SQL query with its **plan as a graph**. *What exactly did Spark run for this line of code?* (Older Spark versions call this tab **SQL**.)

The chain from your code to a number is always the same: **code line → query (SQL / DataFrame tab) → job → stage → task**.

---

# Part B — Nine steps, nine footprints

## 1. A job, its stages and its tasks

**Goal:** Read one complete job: from the Jobs tab down to a single task.

Create the label, define the CSV reader with an explicit schema, and ask which jobs exist so far:

```python
step("S1", "read csv with explicit schema, count")
meter_schema = (
    "ts_utc STRING, station_id STRING, device_id STRING, phase STRING, "
    "active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE, "
    "current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE, "
    "transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, "
    "comm_status STRING")
meter = spark.read.option("header", True).schema(meter_schema).csv(meter_csv)
jobs("S1")
```

The list is empty (`[]`): reading is **lazy**, no job has run. Now trigger an action:

```python
print(meter.count())
jobs("S1")
```

You should see **15** rows and, on this platform, **two** job ids in the list (for example `[0, 1]`): one `count()`, two jobs. The reason follows below. Reload the History Server (wait about 10 seconds if the jobs are missing).

> **SCREENSHOT** `images/04-jobs-tab-s1.png`: the Jobs tab with the two rows `S1: read csv with explicit schema, count`, their durations, stages (succeeded/total) and tasks (progress bar), and the event timeline above.
<!-- ![Jobs tab after S1](images/04-jobs-tab-s1.png) -->

**Look at (Jobs tab):**

- The **Description** is your label, and the **Job Ids** equal the ids your code printed. The column header shows the job group in brackets: `0 (S1)`.
- **Stages: succeeded/total** and **Tasks: succeeded/total**: you ran one `count()`, yet there are two jobs. Open the **Stages** tab too: it lists **two completed stages and one skipped stage**. The next paragraphs explain why.
- Expand **Event Timeline**: each bar is a job; the green markers show when executors were added. Executors start on demand, so your first job often includes the wait for containers.

Click the job description to open the **job page**.

> **SCREENSHOT** `images/05-job-detail-dag-s1.png`: the job page with the DAG Visualization expanded of the second job (a skipped stage box, the Exchange, the final stage) and the stages table below.
<!-- ![Job page with DAG](images/05-job-detail-dag-s1.png) -->

**Look at (job page):**

Open both jobs one after the other.

- **First job:** one stage with `FileScan csv` and a partial aggregate (count per partition). It ends at an **Exchange**: the partial counts are written as shuffle files (**Shuffle Write**).
- **Second job:** the final sum. It reads the shuffle files of the first job (**Shuffle Read**). Its DAG also contains the stage of the first job again, marked **skipped**: its output already exists, so it is not run a second time. A skipped stage shows the plain call site (`count at NativeMethodAccessorImpl.java:0`) and no label, because it did not run under your group.
- **Stages table:** note the **stage ids**. Job ids and stage ids are separate counters, so one job can contain stages with other numbers (in the example: job 1 holds the skipped stage 1 and stage 2).
- **Input / Shuffle Write / Shuffle Read** columns: the first stage reads the file (`Input`) and writes its partial counts (`Shuffle Write`), the last stage reads them (`Shuffle Read`).

**Why two jobs and a skipped stage?** The plan of a `count()` has an `Exchange`. With **adaptive query execution** (AQE, `spark.sql.adaptive.enabled`, the value you printed in section 0), Spark first runs the stage below the `Exchange` as a job of its own, looks at the real size of the shuffle data, and only then plans and runs the rest (that is how it can merge small partitions or change a join). The rest is the second job, and the first stage appears in it as *skipped*. With AQE off, the same `count()` is **one job with two stages** and no skipped stage. In the **SQL / DataFrame** tab you see this as **one query that lists both job ids**, and its plan starts with `AdaptiveSparkPlan`.

Click the description of the stage of the first job to open the **stage page**.

> **SCREENSHOT** `images/06-stage-detail-s1.png`: the stage page with Summary Metrics (min / 25th / median / 75th / max), the Aggregated Metrics by Executor and the task table.
<!-- ![Stage page](images/06-stage-detail-s1.png) -->

**Look at (stage page):**

- **Tasks table:** one row per task. A task is the unit of work on one **partition** of the data in one executor. The 15-row file is tiny, so there is typically **one task**.
- **Summary Metrics:** minimum, quartiles and maximum of all tasks for **Duration**, **GC Time**, **Input Size / Records**. With a single task all five columns are equal. From section 4 on they will differ, and that is where you spot problems.
- **Input Size / Records:** about 15 records (the data rows of the CSV) and the file size in bytes.
- **Event Timeline** (button *Show Additional Metrics* → *Event Timeline*): the time of a task split into scheduler delay, deserialization, executor computing time and so on. Almost all of it should be tiny here.

**Check question:** Why does one `count()` over 15 rows produce two jobs and a skipped stage? Which setting would give you one job with two stages?

---

## 2. A job you did not ask for

**Goal:** Find a job that Spark started on its own.

Read the same file again, this time with `inferSchema` instead of a schema. You do not call any action here:

```python
step("S2", "read csv with inferSchema")
meter_inferred = (spark.read.option("header", True)
    .option("inferSchema", True).csv(meter_csv))
jobs("S2")
```

Compare with section 1: the list of job ids is **not empty**, although you ran no action. Spark has to read the whole file once to guess the column types, and it does that inside `.csv(...)`. Look at the schema it found:

```python
meter_inferred.printSchema()
jobs("S2")
```

> **SCREENSHOT** `images/07-jobs-tab-s2-inferschema.png`: the Jobs tab with the `S2: read csv with inferSchema` row, expanded call site / details visible if possible.
<!-- ![inferSchema job](images/07-jobs-tab-s2-inferschema.png) -->

**Look at:**

- Find the `S2` row in the Jobs tab and its stage: it has **Input** (the file is read in full) but no result you ever see.
- Click the stage, open **+details** under the stage description: the call site there reads like `csv at NativeMethodAccessorImpl.java:0`. This is what *every* job description looked like without your label.

On 15 rows this costs milliseconds; on a landing folder with thousands of files it is a full extra pass over the data. That is why the labs use explicit schemas.

**Check question:** Which line of your code started the extra job: the `.csv(...)` or `printSchema()`? How do you know from the printed job ids?

---

## 3. Narrow transformations: one stage, and the plan

**Goal:** Connect a few lines of DataFrame code to a plan graph and to a single-stage job.

Describe the cleansing with three transformations. The second `jobs()` call shows nothing happens until an action:

```python
step("S3", "filter, new column, show")
meter_ok = (meter
    .withColumn("ts_utc", F.to_timestamp("ts_utc"))
    .filter(F.col("quality_flag") == "OK")
    .withColumn("power_w", F.col("active_power_kw") * 1000))
jobs("S3")
```

Print the plan Spark has made, then run the action. `explain()` prints a **text** version of the plan; keep it visible, you will find the same node names in the UI:

```python
# the plan first (no job), then the action
meter_ok.explain()
meter_ok.select("ts_utc", "station_id", "active_power_kw", "power_w").show(5, False)
jobs("S3")
```

You should see five rows (the first five of the 12 `OK` readings) and a new job id.

Open the **SQL / DataFrame** tab.

> **SCREENSHOT** `images/08-sql-tab-s3-plan.png`: the SQL / DataFrame query list on the left (one row per query, with its job ids) and the plan graph of the S3 query.
<!-- ![SQL tab, S3 query](images/08-sql-tab-s3-plan.png) -->

**Look at:**

- The **query list** has one row per query with **Duration** and **Job IDs** (links). This is the bridge: from a query to the job(s) it started.
- Click the query. The **plan graph** reads from bottom to top: `Scan csv` → `Filter` → `Project` → `CollectLimit`. These are the nodes of the `explain()` output above, with real numbers added: **number of output rows** per node (the scan reads the 15 rows, or fewer if the filter was pushed into the scan, see `PushedFilters`; the last node outputs 5).
- Click **Details** under the graph: the text there is the `explain()` output (the physical plan, with the scan's `ReadSchema`, `PushedFilters` and file location).
- Back in the Jobs tab: this job has **one stage**, no `Exchange`. `filter`, `withColumn` and `select` are *narrow* transformations (every output row comes from exactly one input row, no data moves between partitions), so they never start a new stage.

**Check question:** `meter_ok` was defined before the `explain()`. Why is there no job for the `filter`?

---

## 4. Tasks follow partitions

**Goal:** Create data that is big enough to give the UI metrics meaning, and see that tasks = partitions.

The sample CSVs have 15 rows, too little for any interesting metric. From here on you generate 5 million readings for three transformer stations inside Spark (no file, no HDFS). Station `TS-101` gets 70 % of the rows, `TS-204` 20 % and `TS-305` 10 %, and every row has a timestamp between 08:00 and 12:00 on 2026-01-15. The generator is split into **8 partitions**:

```python
step("S4", "build readings_big: 5 million generated rows, 8 partitions")
n_rows = 5_000_000
base_ts = F.lit("2026-01-15 08:00:00").cast("timestamp").cast("long")
readings_big = (spark.range(0, n_rows, 1, 8)
    .withColumn("station_id", F.when(F.col("id") % 10 < 7, "TS-101")
                               .when(F.col("id") % 10 < 9, "TS-204")
                               .otherwise("TS-305"))
    .withColumn("ts_utc", (base_ts + F.col("id") % 14400).cast("timestamp"))
    .withColumn("active_power_kw", 150 + (F.col("id") % 97) * 0.9)
    .withColumn("quality_flag", F.when(F.col("id") % 50 == 0, "WARN").otherwise("OK")))
print("partitions:", readings_big.rdd.getNumPartitions())
```

You should see `partitions: 8`. Nothing has run yet. Count the rows:

```python
print(readings_big.count())
jobs("S4")
```

You should see **5000000**.

> **SCREENSHOT** `images/09-stage-tasks-s4.png`: the stage page of the first S4 stage with eight tasks in the task table and the Summary Metrics (similar durations).
<!-- ![Eight tasks](images/09-stage-tasks-s4.png) -->

**Look at:**

- Open the S4 job and its first stage: the task table has **8 tasks**, one per partition. This is how you tie a UI number back to code: you chose `8` in `spark.range(0, n_rows, 1, 8)`.
- **Summary Metrics:** the eight tasks produce equal slices of the range, so min, median and max **Duration** are close to each other. Keep this picture: it is what *healthy* looks like.
- **Input Size / Records** is empty for this stage: the data is generated, not read from a file.
- The final aggregation (a second job, as in section 1) has **one task**: it sums eight partial counts.

**Check question:** How many tasks would the first stage have if you wrote `spark.range(0, n_rows, 1, 16)`? And what would change in the Summary Metrics?

---

## 5. A shuffle starts a new stage

**Goal:** Find the stage boundary created by `groupBy` and read the shuffle columns.

Average power and number of readings per station and hour. Print the plan before you run it:

```python
step("S5", "shuffle: average power per station and hour")
hourly = (readings_big
    .withColumn("hour_utc", F.date_trunc("hour", F.col("ts_utc")))
    .groupBy("station_id", "hour_utc")
    .agg(F.avg("active_power_kw").alias("avg_power_kw"),
         F.count(F.lit(1)).alias("n")))
hourly.explain()
```

In the plan find `HashAggregate` twice with an `Exchange hashpartitioning(station_id, hour_utc, ...)` in between. **Every `Exchange` is a stage boundary**: the stage below it ends by writing shuffle files, the stage above it starts by reading them. Run it and bring the 12 result rows (3 stations x 4 hours) to the driver:

```python
rows = hourly.collect()
print(len(rows), "result rows")
jobs("S5")
```

> **SCREENSHOT** `images/10-job-dag-s5.png`: the job page of S5 with the DAG showing the Exchange between the scan/partial-aggregate stage and the final aggregate stage, and the stages table with Shuffle Write / Shuffle Read.
<!-- ![Job DAG with shuffle](images/10-job-dag-s5.png) -->

**Look at (job page):**

- The `Exchange` separates two stages. As in section 1, adaptive execution usually runs them as two jobs (compare the ids `jobs("S5")` printed), with the first stage shown as *skipped* in the second job. The first stage has **8 tasks** (your 8 partitions), the second far fewer.
- **Stages table:** the first stage shows **Shuffle Write**, the second shows **Shuffle Read**. Compare the **record counts**: the first stage processed 5,000,000 rows, but it writes only a few dozen. Spark aggregated *within* each partition first (the first `HashAggregate` is the *partial* one) and shuffles only the partial results. That is why a `groupBy` on few keys is cheap even for huge inputs.
- Find the stage that reads the shuffle. The `Exchange` was planned for **200** partitions (`spark.sql.shuffle.partitions`, which you printed), but the stage has only a handful of tasks. With **adaptive query execution** (`spark.sql.adaptive.enabled = true`) Spark merges tiny shuffle partitions at runtime. Look for the node `AQEShuffleRead` (older versions: `CustomShuffleReader`) with *coalesced* in the SQL tab. If adaptive execution is off on your cluster, you see 200 tasks instead, most of them with 0 records.
- **Skipped stages** are the stages whose shuffle output already exists: they are not run again.

Open the **Stages** tab and sort by **Duration**: this is the quickest way to find the slowest stage of a whole application.

**Check question:** The first stage reads 5 million rows. Why is its Shuffle Write only a few dozen records?

---

## 6. Broadcast join or sort-merge join

**Goal:** Compare two joins that give the same answer but have different plans, and recognize **skew**.

A join needs matching keys in one place. Spark has two main ways to get them there: *broadcast* the small table to every executor (no shuffle of the big one), or *shuffle both tables* by the join key and merge them. First the default. The tiny station table is built by hand:

```python
step("S6a", "join with station_ref, broadcast")
station_ref = spark.createDataFrame(
    [("TS-101", "Nord"), ("TS-204", "Sued"), ("TS-305", "West")],
    ["station_id", "region"])
q_broadcast = (readings_big.join(station_ref, "station_id")
    .groupBy("region").count())
q_broadcast.explain()
```

Find `BroadcastExchange` and `BroadcastHashJoin` in the plan. There is no `Exchange` on the big side for the join itself (the only shuffle is the `groupBy` at the end). Run it:

```python
print(q_broadcast.collect())
jobs("S6a")
```

You should see 3.5 million readings for `Nord` (`TS-101`), 1.0 million for `Sued` and 0.5 million for `West`. Now the same question with the `merge` hint, which forces a sort-merge join:

```python
step("S6b", "join with station_ref, sort-merge (hint)")
q_merge = (readings_big.join(station_ref.hint("merge"), "station_id")
    .groupBy("region").count())
q_merge.explain()
```

Find `SortMergeJoin`, two `Sort` nodes and **two** `Exchange hashpartitioning(station_id, ...)`, one for each side. Run it and note the job ids:

```python
print(q_merge.collect())
jobs("S6b")
```

> **SCREENSHOT** `images/11-sql-plan-broadcast.png`: the plan graph of the S6a query (BroadcastExchange and BroadcastHashJoin).
<!-- ![Broadcast join plan](images/11-sql-plan-broadcast.png) -->

> **SCREENSHOT** `images/12-sql-plan-sortmerge.png`: the plan graph of the S6b query (two Exchanges, two Sorts, SortMergeJoin).
<!-- ![Sort-merge join plan](images/12-sql-plan-sortmerge.png) -->

**Look at (SQL / DataFrame tab):** open both queries one after the other. The broadcast plan has fewer nodes and fewer exchanges. In the sort-merge plan the exchange on the big side shows **shuffle records written** of about **5,000,000**: *every row* is shuffled. In the **Jobs** tab look up the ledger ids of `S6a` and `S6b`: how many stages does each variant need, and how much **Shuffle Write** does the sort-merge variant produce (tens of MB, against a few KB in section 5)? You may also see jobs labelled `broadcast exchange` in the Jobs tab: Spark starts them itself to build the broadcast table, they are not in your ledger.

> **SCREENSHOT** `images/13-stage-skew-s6b.png`: the stage page of the S6b stage that reads the shuffle of the big side, with Summary Metrics showing a maximum far above the median for Duration and Shuffle Read Size / Records, and the task table sorted by duration.
<!-- ![Skewed stage](images/13-stage-skew-s6b.png) -->

**Look at (skew):** open the stage after the shuffle in the sort-merge job. Only three station keys exist, so at most three tasks receive data, and they do **not** receive equal shares: `TS-101` holds 70 % of the rows. In **Summary Metrics**, compare **max** with **median** for **Shuffle Read Size / Records** and for **Duration**. In the task table sort by **Duration** (click the header): the longest task reads about 3.5 million records, the shortest about 0.5 million. This is **data skew**: the stage is as slow as its slowest task, while the other executors wait. A max that is many times the median is the signature to look for in real applications.

**Check question:** The broadcast variant needs no shuffle for the join. Why can it not be used when *both* tables are large?

---

## 7. Cache and the Storage tab

**Goal:** Find a cached DataFrame and see how the second action gets cheaper.

Keep the readings with quality flag `OK` in memory. `cache()` is lazy too: nothing is stored until an action reads the data.

```python
step("S7", "cache readings_ok, two actions")
readings_ok = readings_big.filter(F.col("quality_flag") == "OK").cache()
jobs("S7")
```

The first action below fills the cache (it has to compute everything), the second one reads from it:

```python
# the first action fills the cache, the second one reads from it
print(readings_ok.count())
print(readings_ok.groupBy("station_id").count().collect())
jobs("S7")
```

You should see about 4.9 million readings and three station counts, and two or more job ids.

> **SCREENSHOT** `images/14-storage-tab.png`: the Storage tab with one entry (RDD name, storage level, cached partitions, fraction cached, size in memory, size on disk).
<!-- ![Storage tab](images/14-storage-tab.png) -->

**Look at (Storage tab):**

- One entry for `readings_ok`. It has no variable name; its name is built from the plan of the DataFrame. **Cached Partitions** is 8 (your partitions), **Fraction Cached** should be 100 %, and **Size in Memory** shows how much space 4.9 million rows take in the columnar cache. A fraction below 100 % or a **Size on Disk** above 0 means the executors did not have enough memory for all of it.
- Click the entry: a table shows which executor holds which partition.
- Compare the two S7 queries in the **SQL / DataFrame** tab: the second query has an `InMemoryTableScan` node instead of the range generator, and its first stage is **much shorter** than in the first query (compare the durations in the Jobs tab).

Release the memory and reload the Storage tab. The entry disappears:

```python
_ = readings_ok.unpersist()
```

**Check question:** If you had skipped `cache()`, what would the second action have done?

---

## 8. Write Parquet: tasks, files and output metrics

**Goal:** Relate the output columns of a write stage to the files on HDFS and to partition pruning on the read side.

Write the readings as Parquet, one folder per station (the curated layer pattern from the Spark basics lab). The cache was released, so Spark computes the data again:

```python
step("S8", "write parquet partitioned by station_id, read back")
readings_ok.write.mode("overwrite").partitionBy("station_id").parquet(out_path)
jobs("S8")
```

Open the S8 job. In the stage page of the write stage the task table has an **Output Size / Records** column: the records per task add up to about 4.9 million. In the **SQL / DataFrame** tab the write is a query too: the top node is `InsertIntoHadoopFsRelationCommand` (the command), with metrics such as **number of written files** and **written output**.

> **SCREENSHOT** `images/15-sql-write-metrics.png`: the S8 write query in the SQL tab with the node metrics (number of written files, written output, number of output rows).
<!-- ![Write metrics](images/15-sql-write-metrics.png) -->

Compare with the files. In a **second terminal** on the edge node (valid ticket, same `WORKSHOP_HOME`), or from your handout's HDFS UI:

```bash
# one directory per station
hdfs dfs -ls "${WORKSHOP_HOME}/spark-history-out"

# the part files of one station
hdfs dfs -ls "${WORKSHOP_HOME}/spark-history-out/station_id=TS-305"
```

You should see one `station_id=...` directory per station, and several Parquet part files in each of them. The number of written files in the UI equals the number of files you count.

Now read the data back and ask for one station only:

```python
# read it back: a different scan node, and only one station directory is needed
back = spark.read.parquet(out_path)
one_station = back.filter(F.col("station_id") == "TS-305")
one_station.explain()
print(one_station.count())
jobs("S8")
```

You should see about 0.5 million rows. In the plan find `FileScan parquet` with `PartitionFilters: [..., (station_id = TS-305)]`: Spark skips the other station folders entirely. In the SQL tab compare **number of files read** and **size of files read** of this scan with the number of files you listed.

**Check question:** The stage has 8 tasks and there are 3 stations. How many part files does Spark write, and why?

---

## 9. A failing job

**Goal:** Read a failure in the History Server: failed job, failed stage, task attempts, error and logs.

> 🔴 **Failure case — an error is expected here.** A Python function raises an error on one specific row. You run it, read the message, and then find the failure in the UI. Your application stays alive.

First define the function and the label. It fails for the id `4242`, which lives in the first of four partitions:

```python
step("S9", "FAILURE CASE: python udf raises on one row")

def risky(x):
    # one bad row, like a corrupt reading
    if x == 4242:
        raise ValueError(f"bad reading with id {x}")
    return float(x)

risky_udf = F.udf(risky, "double")
```

Run the failing action. Nothing is wrong with your Spark session; one task cannot finish:

```python
# FAILURE CASE: expected to fail with "Job aborted due to stage failure ... bad reading with id 4242"
(spark.range(0, 100000, 1, 4)
    .select(risky_udf("id").alias("v"))
    .agg(F.sum("v"))
    .collect())
```

You should get a long error that ends with `Job aborted due to stage failure: Task 0 in stage ... failed 4 times` and `ValueError: bad reading with id 4242`. (In the notebook the cell turns red.) Print the job ids of the step, then reload the History Server:

```python
jobs("S9")
```

> **SCREENSHOT** `images/16-jobs-tab-failed.png`: the Jobs tab with the section *Failed Jobs* (the S9 job, with its failure reason in the status column).
<!-- ![Failed job](images/16-jobs-tab-failed.png) -->

**Look at (Jobs tab):** the job is listed under **Failed Jobs**. Click it: a **Failed Stages** section holds the stage, with a short reason. Click the stage.

> **SCREENSHOT** `images/17-failed-task-attempts.png`: the stage page with the task table: task index 0 with attempts 0, 1, 2, 3 all FAILED and the Errors column with the ValueError, the other three tasks SUCCESS or KILLED.
<!-- ![Task attempts](images/17-failed-task-attempts.png) -->

**Look at (stage page):**

- **Task table:** task index **0** appears **four times** with **Attempt** 0, 1, 2, 3 and status `FAILED`. Spark retries a failed task up to `spark.task.maxFailures` times (the value you printed in section 0), and then aborts the job. The other tasks of the stage are `SUCCESS` or `KILLED`.
- **Errors column:** the exception text of each attempt. For Python code you find `PythonException` with the Python traceback, ending in your `ValueError`. The traceback names your function `risky`: here the UI points straight into your code.
- **Executor ID / Logs:** the **stderr** and **stdout** links open the log of the container that ran the attempt. After the application has ended you get the same logs with `yarn logs -applicationId <application-id>` (log aggregation).
- In the **Stages** tab the stage is under **Failed Stages**; in the **SQL / DataFrame** tab the query has status `FAILED`.

Run a normal action to confirm the application survived. The failed job does not affect your other steps:

```python
print(spark.range(10).count())
```

**Check question:** Why did Spark run the failing task four times instead of failing at the first error? Would a retry help if the data itself is bad?

---

# Part C — Wrap-up

## 10. End the application and read it as completed

**Goal:** See the difference between a running (incomplete) and a finished application, and read the application-wide tabs.

Before you end the application, print the ledger: it lists every step and its job ids, in the order of the Jobs tab. This is your key to the history.

```python
for key in ledger:
    jobs(key)
print("application id:", sc.applicationId)
```

Compare it with the Jobs tab of your application: every id belongs to the step with the same label. Press Enter once more after the loop. Then end the application:

- **`pyspark3`:** `exit()` or Ctrl-D.
- **Notebook:** run the last cell, `%spark delete -s spark_history`. Closing the notebook alone does not stop the application.

Reload the History Server, open the **default** list (without *Show incomplete applications*): your application is there now, with a **Completed** time and a **Duration**. The Spark driver wrote its last events when it stopped, and the History Server marks the log as finished.

> **SCREENSHOT** `images/18-history-completed.png`: the default application list with your application now completed (Completed and Duration filled in).
<!-- ![Completed application](images/18-history-completed.png) -->

Open the application and go through the application-wide tabs.

**Jobs.** The event timeline now ends with executors *removed*. Scan the list: which of your steps was the most expensive? Compare duration and the number of tasks, not only the number of jobs.

**Executors.** The driver and every executor of your application, **dead** now. Executors are started and removed on demand (dynamic allocation), so you may see more executors than at the beginning.

> **SCREENSHOT** `images/19-executors-tab.png`: the Executors tab: the summary row (Active / Dead / Total) and one row per executor with cores, task time (GC time), input, shuffle read, shuffle write and logs.
<!-- ![Executors tab](images/19-executors-tab.png) -->

Read per executor: **Task Time (GC Time)** (GC above about 10 % of the task time is highlighted in red: the executor was short of memory), **Input**, **Shuffle Read / Write** (how the work was spread) and the **stdout / stderr** links.

**Environment.** Use the search box (`spark.eventLog`, `spark.sql.adaptive`, `spark.sql.shuffle.partitions`, `spark.dynamicAllocation`) and compare with the values you printed in section 0.

> **SCREENSHOT** `images/20-environment-tab.png`: the Environment tab with the Spark Properties table filtered for `eventLog` or `adaptive`.
<!-- ![Environment tab](images/20-environment-tab.png) -->

The tab also lists system properties and the classpath: the same page answers "why did this application behave this way?" long after it ended.

**Storage** is empty again: the cache dies with the application, as do the variables in your session.

Fill in the table for the steps below, from the UI (one example is given). Compare with a neighbour:

| Step | Job ids (from the ledger) | Stages | Tasks | The number that tells the story |
|------|---------------------------|--------|-------|---------------------------------|
| S1 count | | 2 + 1 skipped (typically) | | Input records |
| S5 shuffle | | | | Shuffle Write records |
| S6b sort-merge | | | | max vs median Shuffle Read |
| S7 cache | | | | Fraction Cached |
| S9 failure | | | | Attempt 0–3 |

**Check question:** Your colleague sends you only an application id for a job that ran last night. List the pages you would open, in order, to find out whether it was slow, and why.

---

## Stretch (optional)

- Run section 1 and section 5 again with `spark.conf.set("spark.sql.adaptive.enabled", "false")` and compare: number of jobs, skipped stages, and the number of tasks of the shuffle-reading stage. Set it back to `"true"` afterwards.
- Compare `readings_big.repartition(2)` and `readings_big.repartition(64)` followed by a `count()`: how do **tasks**, **task duration** and **scheduler delay** change?
- Download the **Event Log** of your application from the application list (or from HDFS as in the Spark basics lab) and find `SparkListenerJobStart`, `SparkListenerStageCompleted` and `SparkListenerTaskEnd` lines: the History Server pages are built from these.
- Build the query of section 6a again after `spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")`: the plan switches to `SortMergeJoin` without any hint. Reset it with the value you printed in section 0.

Remove the output of section 8 when you are done:

```bash
# delete the Parquet folder of the lab
hdfs dfs -rm -r -f "${WORKSHOP_HOME}/spark-history-out"
```

This lab has no `check.sh`: you are finished when the ledger matches the Jobs tab, your application is listed as completed, and you can name for each tab the question it answers.

---
*The generation of these labs was supported by AI.*
