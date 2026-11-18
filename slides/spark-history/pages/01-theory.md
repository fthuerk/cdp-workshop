---
layout: section
---

# Theory

Where the History Server sits and how to read what it shows

---

# Why a History Server?

- Every Spark application has its own **Spark UI**: jobs, stages, tasks, plans, cache, executors
- That UI is served by the **driver**. When the application ends, the driver is gone and **the UI disappears**
- The **History Server** keeps the UI: it shows the same pages for **finished** applications, days later
- Typical questions it answers: *Why was last night's job slow? Which stage failed? Was the data skewed?*

<div class="grid grid-cols-2 gap-4 mt-6 text-sm">
<div class="rounded border-2 border-gray-500/40 p-2">
  <b>Without it:</b> only <code>yarn logs</code>. Text, no stages, no plans, no timings per task.
</div>
<div class="rounded border-2 border-green-500/60 bg-green-500/10 p-2">
  <b>With it:</b> the full Spark UI of every finished application, searchable by user and name.
</div>
</div>

---

# Where it sits: it reads files, not applications

<svg viewBox="0 0 900 275" width="100%" class="mt-1" style="font-size:13px" fill="currentColor">
<defs>
  <marker id="sh-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M0,0 L10,5 L0,10 z" fill="currentColor"/>
  </marker>
</defs>

<!-- application -->
<rect x="10" y="10" width="250" height="150" rx="10" fill="rgba(34,197,94,0.10)" stroke="#22c55e" stroke-width="2"/>
<text x="135" y="30" text-anchor="middle" font-weight="bold">Spark application (YARN)</text>
<rect x="25" y="45" width="220" height="42" rx="5" fill="rgba(128,128,128,0.14)" stroke="rgba(128,128,128,0.7)" stroke-width="1.2"/>
<text x="135" y="64" text-anchor="middle" font-weight="bold">Driver</text>
<text x="135" y="79" text-anchor="middle" style="font-size:11px">plans jobs, serves the live UI</text>
<rect x="25" y="100" width="220" height="42" rx="5" fill="rgba(128,128,128,0.14)" stroke="rgba(128,128,128,0.7)" stroke-width="1.2"/>
<text x="135" y="119" text-anchor="middle" font-weight="bold">Executors</text>
<text x="135" y="134" text-anchor="middle" style="font-size:11px">run tasks, report metrics</text>

<!-- event log on HDFS -->
<rect x="340" y="45" width="200" height="90" rx="10" fill="rgba(128,128,128,0.10)" stroke="rgba(128,128,128,0.8)" stroke-width="2"/>
<text x="440" y="70" text-anchor="middle" font-weight="bold">HDFS: event log</text>
<text x="440" y="90" text-anchor="middle" style="font-size:11px">one JSON file per application</text>
<text x="440" y="108" text-anchor="middle" style="font-size:11px;font-family:monospace">spark.eventLog.dir</text>

<!-- history server -->
<rect x="640" y="10" width="250" height="150" rx="10" fill="rgba(59,130,246,0.10)" stroke="#3b82f6" stroke-width="2"/>
<text x="765" y="30" text-anchor="middle" font-weight="bold">Spark History Server</text>
<text x="765" y="45" text-anchor="middle" style="font-size:11px">separate service (role in Cloudera Manager)</text>
<rect x="655" y="60" width="220" height="42" rx="5" fill="rgba(128,128,128,0.14)" stroke="rgba(128,128,128,0.7)" stroke-width="1.2"/>
<text x="765" y="78" text-anchor="middle">scans the directory</text>
<text x="765" y="93" text-anchor="middle" style="font-size:11px">every few seconds</text>
<rect x="655" y="110" width="220" height="42" rx="5" fill="rgba(128,128,128,0.14)" stroke="rgba(128,128,128,0.7)" stroke-width="1.2"/>
<text x="765" y="128" text-anchor="middle">rebuilds the UI pages</text>
<text x="765" y="143" text-anchor="middle" style="font-size:11px">from the events</text>

<!-- browser -->
<rect x="340" y="205" width="200" height="50" rx="8" fill="rgba(128,128,128,0.14)" stroke="rgba(128,128,128,0.8)" stroke-width="2"/>
<text x="440" y="226" text-anchor="middle" font-weight="bold">Your browser</text>
<text x="440" y="243" text-anchor="middle" style="font-size:11px">Kerberos or LDAP login</text>

<!-- arrows -->
<line x1="260" y1="90" x2="340" y2="90" stroke="currentColor" stroke-width="1.5" marker-end="url(#sh-arrow)"/>
<text x="300" y="80" text-anchor="middle" style="font-size:11px">writes</text>
<text x="300" y="107" text-anchor="middle" style="font-size:11px">events</text>
<line x1="540" y1="90" x2="640" y2="90" stroke="currentColor" stroke-width="1.5" marker-end="url(#sh-arrow)"/>
<text x="590" y="80" text-anchor="middle" style="font-size:11px">read by</text>
<polyline points="540,230 765,230 765,160" fill="none" stroke="currentColor" stroke-width="1.5" marker-end="url(#sh-arrow)"/>
<text x="655" y="222" text-anchor="middle" style="font-size:11px">history pages (finished apps)</text>
<polyline points="135,160 135,230 340,230" fill="none" stroke="currentColor" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#sh-arrow)"/>
<text x="140" y="190" style="font-size:11px">live UI: served by the driver,</text>
<text x="140" y="203" style="font-size:11px">YARN only forwards (proxy)</text>
</svg>

<div class="grid grid-cols-2 gap-4 mt-2 text-xs">

<div class="border-l-4 border-green-500 pl-3">
  <b>Live Spark UI</b> (while the application runs): a small web server <b>inside the driver</b>. YARN does not host it; the ResourceManager link only <b>forwards</b> to it. The driver is on the edge node with <code>pyspark3</code> (client mode), in a YARN container in cluster mode and in a Livy session. It <b>disappears</b> when the driver exits.
</div>

<div class="border-l-4 border-blue-500 pl-3">
  <b>History Server</b> (any time later): the <b>same UI code</b>, fed by <b>replaying the event log</b> instead of live objects. It never talks to the application. After the application ends, the ResourceManager link switches to it.
</div>

</div>

<div class="mt-2 text-sm text-center">The driver only <b>writes</b>, the History Server only <b>reads</b>: if the file is there, the UI exists.</div>

---

# Running or completed?

| | Running application | Completed application |
|---|---|---|
| Event log | Still growing (flushed at job and stage end) | Closed when the application stops |
| In the History Server | Under **Show incomplete applications**, with a short delay | In the default list, with *Completed* and *Duration* |
| Live UI | Yes (driver, through the YARN proxy) | Gone |
| Executors tab | Active executors | All **dead**, but still listed |

- A **notebook or `pyspark3` session** is a running application until you end it: *incomplete* in the History Server, though you were done an hour ago
- The event log is also your **debugging file**: download it, every `Spark*` line is one event
- Old logs are **cleaned up** after a retention period, so keep what you need

---

# Anatomy: the levels of an application

<div class="grid grid-cols-4 gap-2 mt-2 text-xs">

<div class="rounded-lg border-2 border-gray-500/50 p-2">
  <div class="font-bold text-base">Application</div>
  <div class="mt-1">One <code>SparkSession</code>: everything you run until you end it</div>
  <div class="mt-2"><b>Id:</b> <code>application_...</code></div>
  <div><b>UI:</b> the History Server list; all tabs belong to one application</div>
</div>

<div class="rounded-lg border-2 border-blue-500/60 bg-blue-500/10 p-2">
  <div class="font-bold text-base">Job</div>
  <div class="mt-1">Work started by an <b>action</b>: <code>count</code>, <code>show</code>, <code>collect</code>, <code>write</code></div>
  <div class="mt-2"><b>Id:</b> 0, 1, 2, ... (own counter)</div>
  <div><b>UI:</b> <b>Jobs</b> tab, job page with DAG</div>
</div>

<div class="rounded-lg border-2 border-purple-500/60 bg-purple-500/10 p-2">
  <div class="font-bold text-base">Stage</div>
  <div class="mt-1">A part of a job that needs <b>no shuffle</b>. A new stage starts at every <code>Exchange</code></div>
  <div class="mt-2"><b>Id:</b> 0, 1, 2, ... (own counter)</div>
  <div><b>UI:</b> <b>Stages</b> tab, stage page with Summary Metrics</div>
</div>

<div class="rounded-lg border-2 border-green-500/60 bg-green-500/10 p-2">
  <div class="font-bold text-base">Task</div>
  <div class="mt-1">One <b>partition</b> of a stage, run on one executor. A failed task is retried: new <b>attempt</b></div>
  <div class="mt-2"><b>Id:</b> task index + attempt</div>
  <div><b>UI:</b> task table of a stage page</div>
</div>

</div>

<div class="mt-3 text-xs text-center opacity-80">
1 application contains many jobs, a job contains stages, a stage contains tasks (one per partition)
</div>

<div class="mt-3 p-2 rounded bg-blue-500/10 text-sm">

**Example from the lab:** one `count()` with adaptive execution shows **1 application, 2 jobs** (ids 0 and 1), **3 stages** (0 and 2 ran, 1 was *skipped*), and one task per stage for the tiny CSV. Job ids and stage ids are separate counters.

</div>

<div class="mt-3 text-xs">

- **Code to number:** code line → query → job → stage → task
- **Lazy:** transformations (`filter`, `select`, `join`) start nothing. Jobs appear at actions; Spark also starts some on its own (`inferSchema`)
- **Tasks = partitions:** you can predict the number of tasks from your code
- **Adaptive execution (AQE):** runs the stage below a shuffle first as its own job, looks at the real data size, then plans the rest. That is why one action can be **two jobs** and a stage can be **skipped** (its shuffle output already exists)

</div>

---

# One tab, one question

<div class="grid grid-cols-3 gap-4 mt-4 text-sm">

<div class="border-l-4 border-blue-500 pl-3">
  <div class="font-bold text-base">Jobs</div>
  <div class="mt-1 opacity-80">Which action was slow or failed? Event timeline, DAG per job.</div>
</div>

<div class="border-l-4 border-purple-500 pl-3">
  <div class="font-bold text-base">Stages</div>
  <div class="mt-1 opacity-80">Where does the time go? Tasks, shuffle read and write, summary metrics.</div>
</div>

<div class="border-l-4 border-green-500 pl-3">
  <div class="font-bold text-base">SQL / DataFrame</div>
  <div class="mt-1 opacity-80">What did Spark run for this line? The plan as a graph, with row counts.</div>
</div>

<div class="border-l-4 border-orange-500 pl-3">
  <div class="font-bold text-base">Storage</div>
  <div class="mt-1 opacity-80">What is cached, how big, how much of it fits?</div>
</div>

<div class="border-l-4 border-gray-500 pl-3">
  <div class="font-bold text-base">Executors</div>
  <div class="mt-1 opacity-80">Who did the work? GC time, shuffle totals, links to logs.</div>
</div>

<div class="border-l-4 border-gray-500 pl-3">
  <div class="font-bold text-base">Environment</div>
  <div class="mt-1 opacity-80">Which settings applied? Adaptive execution, shuffle partitions, event log.</div>
</div>

</div>

---

# What to look for

| You see | Where | Usually means |
|---------|-------|---------------|
| One task far above the **median** (max is many times median) | Stage → Summary Metrics, task table | **Data skew**: one key holds most rows |
| Huge **Shuffle Write** | Stages, job page | A shuffle of whole rows, for example a sort-merge join |
| **GC time** highlighted red (above about 10 %) | Executors | Memory pressure |
| **Spill** (memory or disk) | Stage page | Shuffle partitions too big for memory |
| Thousands of tiny tasks | Stage page | Too many partitions or small files |
| Same task with **attempts 0 to 3** all failed | Stage → task table, *Errors* column | An error that repeats; read the exception |
| **Fraction cached** below 100 % | Storage | The cache does not fit in memory |

<div class="mt-4 text-sm">

Start at the **Jobs** tab, sort the **Stages** tab by *Duration*, then open the slowest stage and compare **max** with **median**.

</div>

---

# Linking the UI back to your code

PySpark job descriptions look like `count at NativeMethodAccessorImpl.java:0`: they never point at your line. The lab uses four ways to find your code in the UI:

<div class="grid grid-cols-2 gap-4 mt-4 text-sm">

<div class="rounded border-2 border-blue-500/50 p-3">
  <b>1. Job labels.</b> <code>sc.setJobGroup("S3", "S3: filter + show")</code> puts your text in the Description column of every job and stage.
</div>

<div class="rounded border-2 border-purple-500/50 p-3">
  <b>2. Job-id ledger.</b> <code>statusTracker().getJobIdsForGroup(...)</code> prints the job ids a step started. Look for exactly those ids.
</div>

<div class="rounded border-2 border-green-500/50 p-3">
  <b>3. <code>explain()</code> next to the plan.</b> The node names (<code>Scan</code>, <code>Filter</code>, <code>HashAggregate</code>, <code>Exchange</code>) are the same in the text and in the SQL / DataFrame graph.
</div>

<div class="rounded border-2 border-orange-500/50 p-3">
  <b>4. Partitions = tasks.</b> <code>df.rdd.getNumPartitions()</code> tells you how many tasks the stage must have.
</div>

</div>

---

# The lab: one application, nine steps

<div class="text-sm">

You start **one** Spark application (`pyspark3` or a Livy notebook) and, after each step, look it up in the History Server:

| Step | Footprint in the UI |
|------|---------------------|
| 1–3 | A job with its stages and tasks; a job you did not ask for; one stage and its plan |
| 4–5 | Tasks follow partitions; a shuffle splits the job |
| 6 | Broadcast against sort-merge join, and skew |
| 7–8 | Cache in the Storage tab; Parquet write and partition pruning |
| 9 | A failing job with four task attempts (a marked failure case) |
| 10 | End the application: *incomplete* becomes *completed* |

</div>

<div class="mt-3 p-2 rounded bg-blue-500/10 text-sm">
Keep the History Server open next to your terminal or notebook. Reload it after each step; a new job can take about 10 seconds to appear.
</div>
