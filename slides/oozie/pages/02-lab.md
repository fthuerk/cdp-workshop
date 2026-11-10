---
layout: statement
---

# Part 2: Lab

Oozie in Hue, built with the mouse

---

# Lab overview

You work in the **Hue web UI** only. After each build you look at the XML Hue generated. **Do not edit the XML**.

<div class="text-sm">

| Section | You build | You look at |
|---------|-----------|-------------|
| 0 | Nothing: find your way around | Menus, Job Browser |
| 1 | Workflow `hello-wf` (shell + fs action) | `workflow.xml` |
| 2 | Break it on purpose | Failed action, kill node |
| 3 | Time-based schedule | `coordinator.xml`, nominal time |
| 4 | Hive load triggered by data | Dataset, done-flag, Hive action, daily partition |
| 5 | Clean up | |

</div>

<div class="mt-2 p-2 rounded bg-yellow-500/10 text-sm">

`<your_user>` is your `WORKSHOP_USER` (the short name you use with `kinit`). Names contain it so that your jobs are easy to find on the shared Oozie server. The lab needs one output folder, `/user/<your_user>/oozie_lab`, which the workflow creates itself.

</div>

---
layout: section
---

# 0. Orient

Find the editors and the Job Browser in Hue

---

# 0. Orient: the Scheduler menu

<div class="grid grid-cols-[1.4fr_1fr] gap-8 items-start">
<div>

**Goal:** Know where workflows, schedules and running jobs live in Hue.

1. Open Hue and log in with your user.
2. In the left menu open **Scheduler**: **Workflow**, **Schedule**, **Bundle**.
3. Below: **Documents**, **Storage Browser** (HDFS), **Tables**, **Jobs**, **Importer**.

</div>
<div>

<img src="/images/0_hue_oozie_navigation.png" class="rounded shadow max-h-[24rem] mx-auto" />

</div>
</div>

---

# 0. Orient: the Job Browser

Open **Jobs**. Tabs: **Workflows**, **Schedules** (coordinators), **Bundles**, **SLAs**. Everything Oozie starts shows up here, also its launchers (type *Oozie Launcher*). Filter your own jobs with:

```text
user:<your_user>
```

<img src="/images/0_jobs_browser_with_workflow_tab.png" class="rounded shadow w-full" />

---
layout: section
---

# 1. Create a workflow

Shell + Fs action, run it, read the XML

---

# 1.1 Build it

<div>

1. **Scheduler → Workflow**: an empty canvas with **Start** and **End** appears. Name the workflow:

```text
hello-wf-<your_user>
```

2. Drag an **Fs** action between start and end. Name it `make_dir`, operation **Create directory**, path:

```text
/user/<your_user>/oozie_lab
```

3. Drag a **Shell** action behind it. Name it `say_hello`, command:

```text
echo
```

   Arguments, one per line: `hello` and `world`.

4. The flow runs Start, `make_dir`, `say_hello`, End. The grey square is the **Kill** node Hue added. **Save**.

</div>

---

# 1.1 The canvas

<img src="/images/1_workflow.png" class="rounded shadow w-full mt-4" />

---

# 1.1 Transitions

Open the action settings (blue gear icon in the action's top right corner) and choose the **Transitions** tab of `make_dir`.

- **OK** points to the next action
- **KO** points to the Kill node
- Do not change them

<img src="/images/1_transitions.png" class="rounded shadow mt-2 max-h-56 mx-auto" />

---

# 1.2 Run it and follow the job

1. Click **Submit** (play icon) and confirm the small window. Do not change anything; Hue fills in the parameters.
2. Hue opens the Job Browser. Refresh until **SUCCEEDED**. The **Graph** tab shows the same flow; finished actions are green.
3. The job ID ends in `-oozie-oozi-W`: `W` stands for workflow.

<img src="/images/1_2_finished_job_browser.png" class="rounded shadow w-full mt-4" />

---

# 1.2 The Fs action log

Open the **Logs** tab and find the line of the Fs action (`make_dir`):

<div class="font-mono text-xs break-all p-3 rounded bg-gray-500/10 my-4">
2026-11-02 11:50:55,814 INFO THREAD[CallableQueue-11] org.apache.oozie.action.hadoop.FsActionExecutor: SERVER[&lt;oozie-server&gt;] USER[&lt;your_user&gt;] GROUP[-] TOKEN[] APP[hello-wf-&lt;your_user&gt;] JOB[0000012-261023121531177-oozie-oozi-W] ACTION[0000012-261023121531177-oozie-oozi-W@fs-5b32] Creating directory [hdfs://nameservice1/user/&lt;your_user&gt;/oozie_lab]
</div>

`FsActionExecutor` runs **inside the Oozie server**. There is no YARN application and no MapReduce job for this action.

---

# 1.2 The shell action and YARN

<div class="grid grid-cols-2 gap-6">
<div class="text-sm">

1. Back in the **Graph** tab, click the shell action.
2. **Properties** show:
   - `externalId`: the YARN application of this action
   - `data`: the captured output (`hello=world`)
3. Follow the application link to YARN and open its log: the output is `hello world`.

An `echo` is a real process, so it needs a container. Oozie starts a small **launcher** application on YARN. That is why the shell action has an `externalId` and the Fs action has none.

</div>
<div>

<img src="/images/1_3_shell_action_properties.png" class="rounded shadow" />

</div>
</div>

---

# 1.3 Look at the XML

In the job page open the **XML** tab. It shows the `workflow.xml` that Hue generated and Oozie ran. **Do not edit it.**

<img src="/images/1_3_xml_tab.png" class="rounded shadow w-full mt-4" />

---

# 1.3 workflow.xml and what each part is

<style>
.slidev-code { font-size: 0.58rem !important; line-height: 0.98rem !important; }
</style>

<div style="position:relative;width:868px;height:430px;margin-top:6px">
<div style="position:absolute;left:0;top:0;width:560px">

```xml
<workflow-app name="hello-wf-<your_user>" xmlns="uri:oozie:workflow:0.5">
    <start to="fs-5b32"/>
    <kill name="Kill">
        <message>Action failed, error message[${wf:errorMessage(wf:lastErrorNode())}]</message>
    </kill>
    <action name="fs-5b32">
        <fs>
              <mkdir path='${nameNode}/user/<your_user>/oozie_lab'/>
        </fs>
        <ok to="shell-d6bc"/>
        <error to="Kill"/>
    </action>
    <action name="shell-d6bc">
        <shell xmlns="uri:oozie:shell-action:0.1">
            <job-tracker>${jobTracker}</job-tracker>
            <name-node>${nameNode}</name-node>
            <exec>echo</exec>
              <argument>hello</argument>
              <argument>world</argument>
              <capture-output/>
        </shell>
        <ok to="End"/>
        <error to="Kill"/>
    </action>
    <end name="End"/>
</workflow-app>
```

</div>
<svg style="position:absolute;left:0;top:0;pointer-events:none" width="868" height="430" viewBox="0 0 868 430">
<rect x="6" y="23.7" width="548" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="32.5" x2="596" y2="63.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="39.4" width="548" height="49.0" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="63.9" x2="596" y2="117.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="86.4" width="548" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="95.2" x2="596" y2="171.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="102.1" width="548" height="49.0" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="126.6" x2="596" y2="225.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="149.1" width="548" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="158.0" x2="596" y2="279.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="258.9" width="548" height="49.0" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="283.4" x2="596" y2="333.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="384.3" width="548" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="554" y1="393.2" x2="596" y2="387.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
</svg>
<table style="position:absolute;left:596px;top:0;width:272px;font-size:0.66rem;line-height:1.05rem;border-collapse:collapse;table-layout:fixed">
<thead><tr style="height:36px"><th style="width:92px;padding:0 6px">In the UI</th><th style="padding:0 6px">In the XML</th></tr></thead>
<tbody>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">Start node</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;start to="fs-5b32"/&gt;</code>, the first action</td></tr>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">Kill node</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;kill&gt;</code> with a message; <code>&lt;error to="Kill"/&gt;</code> in every action</td></tr>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">Action</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;action name="..."&gt;</code>, name generated by Hue</td></tr>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">Fs operation</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;fs&gt;&lt;mkdir path="..."/&gt;&lt;/fs&gt;</code></td></tr>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">Order on the canvas</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;ok to="..."&gt;</code>, next node on success</td></tr>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">Command, arguments</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;exec&gt;</code> and <code>&lt;argument&gt;</code></td></tr>
<tr style="height:54px"><td style="width:92px;padding:0 6px;height:54px;line-height:1.05rem">End node</td><td style="padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;end name="End"/&gt;</code></td></tr>
</tbody>
</table>
</div>

---

# 1.3 Things to notice

- `${nameNode}` and `${jobTracker}` are **variables**. Hue passes them when it submits.
- The `xmlns` values are the **schema versions** of the workflow and of the action type.
- `${wf:errorMessage(...)}` in the kill node is an **EL function**: it inserts the error message of the failed action.
- `<capture-output/>` keeps the output of the command for later nodes (the `hello=world` in `data`).


---
layout: section
---

# 2. Break it

Fail on purpose and see the kill node

---

# 2. Break it

A `mkdir` on an existing folder is not an error, so a rerun would just succeed. Add a step that fails:

1. Drag a third **Shell** action behind `say_hello`, name `fail_on_purpose`.
   - Command: `ls`
   - Single argument:

```text
/does/not/exist
```

2. **Save** and **Submit**.
3. The workflow ends **KILLED**. The first two actions are green, `fail_on_purpose` is red. Click it for the error message.

---

# 2. The killed workflow

<img src="/images/2_fail_on_purpose.png" class="rounded shadow w-full mt-4" />

---

# 2. What to notice

- The XML has a third `<action>`; `shell-d6bc` now has `<ok to="...">` pointing to it instead of `End`.
- The first two actions ran again and succeeded. **Oozie does not undo them.**
- The kill node uses the error message through `wf:errorMessage(...)`.

**Clean up:** remove `fail_on_purpose` again (the **x** in the action's top right corner) and **Save**, so the workflow succeeds in the next sections.


---
layout: section
---

# 3. Time-based schedule

Coordinator, frequency, nominal time

---

# 3. Coordinator idea

A **coordinator** wraps a workflow. It knows **when** to start it: a frequency, between a start and an end time.

Each start is a **coordinator action** with a **nominal time**: the time the run was *planned* for. It can differ from the time it actually started.

To give each run its own folder, change the `make_dir` path in the workflow to use a variable and **Save**:

```text
/user/<your_user>/oozie_lab/${wf_date}
```

Hue asks for `wf_date` on a manual submit. The coordinator fills it in.

---

# 3.1 Build the schedule

1. **Scheduler → Schedule**, name it:

```text
every-5-min-<your_user>
```

2. **Which workflow to schedule?** `hello-wf-<your_user>`
3. **How often?** tick **Advanced syntax** and enter the crontab (every 5 minutes):

```text
*/5 * * * *
```

4. **From**: now (a few minutes ahead is fine). **To**: 20 minutes later. Keep the time zone.
5. **Parameters**: set `wf_date` to (type it if the list does not offer it):

```text
${coord:formatTime(coord:nominalTime(), 'yyyyMMddHHmm')}
```

6. **Save** and **Submit**

---

# 3.1 The schedule editor

<img src="/images/3_1_coordinator.png" class="rounded shadow w-full mt-4" />

---

# 3.2 coordinator.xml and what each part is

In the Job Browser open **Schedules**, click your coordinator, open its **XML** tab. The `${...}` values come from the properties Hue submitted (see **Configuration** of the job).

<style>
.slidev-code { font-size: 0.58rem !important; line-height: 0.98rem !important; }
</style>

<div style="position:relative;width:868px;height:430px;margin-top:0px">
<div style="position:absolute;left:0;top:0;width:540px">

```xml
<coordinator-app name="every-5-min-<your_user>"
  frequency="*/5 * * * *"
  start="${start_date}" end="${end_date}" timezone="Europe/Berlin"
  xmlns="uri:oozie:coordinator:0.2">
  <controls>
    <execution>FIFO</execution>
  </controls>
  <action>
    <workflow>
      <app-path>${wf_application_path}</app-path>
      <configuration>
        <property>
          <name>wf_date</name>
          <value>${coord:formatTime(coord:nominalTime(), 'yyyyMMddHHmm')}</value>
        </property>
        <!-- Hue adds three more properties of the same form:
             oozie.use.system.libpath, start_date, end_date -->
      </configuration>
    </workflow>
  </action>
</coordinator-app>
```

</div>
<svg style="position:absolute;left:0;top:0;pointer-events:none" width="868" height="430" viewBox="0 0 868 430">
<rect x="6" y="23.7" width="528" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="32.5" x2="576" y2="63.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="39.4" width="528" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="48.2" x2="576" y2="117.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="70.7" width="528" height="49.0" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="95.2" x2="576" y2="171.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="149.1" width="528" height="17.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="158.0" x2="576" y2="225.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="180.5" width="528" height="64.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="212.8" x2="576" y2="279.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="243.2" width="528" height="33.4" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="259.9" x2="576" y2="333.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
</svg>
<table style="position:absolute;left:576px;top:0;width:292px;font-size:0.66rem;line-height:1.05rem;border-collapse:collapse;table-layout:fixed">
<thead><tr style="height:36px"><th style="width:100px;padding:0 6px">In the XML</th><th style="padding:0 6px">Meaning</th></tr></thead>
<tbody>
<tr style="height:54px"><td style="width:100px;padding:0 6px;height:54px;line-height:1.05rem"><code>frequency</code></td><td style="padding:0 6px;height:54px;line-height:1.05rem">Crontab <code>*/5 * * * *</code>: an action every 5 minutes</td></tr>
<tr style="height:54px"><td style="width:100px;padding:0 6px;height:54px;line-height:1.05rem"><code>start</code>, <code>end</code></td><td style="padding:0 6px;height:54px;line-height:1.05rem">The window; one action per interval inside it</td></tr>
<tr style="height:54px"><td style="width:100px;padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;execution&gt;</code></td><td style="padding:0 6px;height:54px;line-height:1.05rem">Order of waiting actions; <code>FIFO</code> = first in, first out</td></tr>
<tr style="height:54px"><td style="width:100px;padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;app-path&gt;</code></td><td style="padding:0 6px;height:54px;line-height:1.05rem">The workflow to start</td></tr>
<tr style="height:54px"><td style="width:100px;padding:0 6px;height:54px;line-height:1.05rem"><code>&lt;property&gt;</code></td><td style="padding:0 6px;height:54px;line-height:1.05rem">Parameters handed to the workflow for this run</td></tr>
<tr style="height:54px"><td style="width:100px;padding:0 6px;height:54px;line-height:1.05rem">Added by Hue</td><td style="padding:0 6px;height:54px;line-height:1.05rem">Three more properties of the same form</td></tr>
</tbody>
</table>
</div>

---

# 3.3 Watch it run and kill it

Job Browser, **Schedules**, click your coordinator. The **Tasks** tab has one row per interval.

- **WAITING**: nominal time not reached yet
- **READY**: action created, waits to start
- then **RUNNING** and **SUCCEEDED**

Wait for at least two **SUCCEEDED** actions. In `/user/<your_user>/oozie_lab` there is one folder per run, named after the nominal time. Kill the schedule when you have seen enough: select it in the Job Browser and click **Kill**.

<img src="/images/3_2_schedules_list.png" class="rounded shadow max-h-44 mx-auto mt-2" />

---
layout: section
---

# 4. Load data when it arrives

Dataset, done-flag, Hive action, daily partition

---

# 4. The idea

A coordinator can wait for a **dataset**: a folder with a **done-flag** file. By convention the flag is an empty file named `_SUCCESS`.

<div class="grid grid-cols-[1fr_auto_1fr_auto_1fr_auto_1fr] gap-1 items-stretch mt-4 text-[0.85rem]">

<div class="rounded-lg border-2 border-gray-500/60 bg-gray-500/10 p-3">
  <div class="font-bold text-sm">1. Producer</div>
  <div class="mt-1">Copies the data files into the landing folder</div>
  <div class="mt-1 font-mono text-[0.62rem]">.../oozie_lab/landing</div>
</div>
<div class="self-center w-4 border-t-2 border-gray-400"></div>

<div class="rounded-lg border-4 border-amber-500 bg-amber-500/15 p-3">
  <div class="font-bold text-sm">2. Producer</div>
  <div class="mt-1">Writes the empty file <b class="font-mono">_SUCCESS</b> <b>last</b></div>
  <div class="mt-1">Meaning: "the data is complete"</div>
</div>
<div class="self-center w-4 border-t-2 border-gray-400"></div>

<div class="rounded-lg border-2 border-blue-500/60 bg-blue-500/10 p-3">
  <div class="font-bold text-sm">3. Coordinator</div>
  <div class="mt-1">The action is <b>WAITING</b> until <span class="font-mono">_SUCCESS</span> exists, then it starts the workflow</div>
</div>
<div class="self-center w-4 border-t-2 border-gray-400"></div>

<div class="rounded-lg border-2 border-green-500/60 bg-green-500/10 p-3">
  <div class="font-bold text-sm">4. Workflow</div>
  <div class="mt-1">Hive action: adds the partition of the day and loads the files (they are moved)</div>
</div>

</div>

<div class="mt-5 text-sm font-bold">What the landing folder looks like when the producer is done:</div>

```text
/user/<your_user>/oozie_lab/landing/
    meter_2026-11-05.csv     <- 1. data file(s) arrive first
    _SUCCESS                 <- 2. empty flag file, written LAST
```

<div class="mt-2 text-sm">

- Flag missing: the action waits in **WAITING**. Flag appears: the workflow starts (file at 14:00 means start at 14:00)
- The **schedule** says *which day* an action is for, the **dataset** says *when it may start*

</div>

---

# 4.1 Create the table

**Editor → Hive**. Run once. `${ws_user}` is the input field Hue shows below the editor: enter your user name.

```sql {maxHeight:'380px'}
CREATE DATABASE IF NOT EXISTS ${ws_user};

CREATE EXTERNAL TABLE IF NOT EXISTS ${ws_user}.landing_meter (
  ts_utc STRING, station_id STRING, device_id STRING, phase STRING,
  active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE,
  current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE,
  transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING,
  comm_status STRING
)
PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1', 'external.table.purge'='true');
```

No `LOCATION`: Hive uses the default warehouse folder. You add **no** partitions and load **no** data yourself. The workflow does that.

---

# 4.2 The Hive script

In **Storage Browser** create the file (**New → File**):

```text
/user/<your_user>/oozie_lab/load_partition.hql
```

Content:

```sql
ALTER TABLE ${ws_user}.landing_meter ADD IF NOT EXISTS PARTITION (dt='${day}');
LOAD DATA INPATH '${landing_dir}' INTO TABLE ${ws_user}.landing_meter PARTITION (dt='${day}');
```

`${landing_dir}` is the landing folder; the coordinator provides it. `LOAD DATA INPATH` **moves** the files out of the landing folder into the partition.

---

# 4.2 The workflow

<div class="grid grid-cols-2 gap-6">
<div class="text-sm">

1. **Scheduler → Workflow**, name:

```text
load-landing-wf-<your_user>
```

2. Drag a **Hive** (HiveServer2) action, name `load_partition`, choose the file as script.
3. Add three **parameters**, one per line:

```text
ws_user=${wf:user()}
day=${wf_date}
landing_dir=${landing_dir}
```

4. **Credentials** tab of the action: tick **hive2** (needed on a Kerberos cluster).
5. **Save**

`wf:user()` is the user who runs the workflow; `wf_date` and `landing_dir` come from the coordinator.

</div>
<div>

<img src="/images/4_2_hive_workflow.png" class="rounded shadow w-full" />

</div>
</div>

---

# 4.3 The schedule

<div class="grid grid-cols-2 gap-6">
<div class="text-sm">

1. **Scheduler → Schedule**, name:

```text
on-landing-<your_user>
```

2. Workflow: `load-landing-wf-<your_user>`
3. **Advanced syntax**, crontab (daily at midnight):

```text
0 0 * * *
```

   **From** today 00:00, **To** a few days later.
4. Set `wf_date` to:

```text
${coord:formatTime(coord:nominalTime(), 'yyyyMMdd')}
```

</div>
<div class="text-sm">

5. For `landing_dir` switch the value type from **Parameter** to **Input Path**:
   - Path:

```text
/user/<your_user>/oozie_lab/landing
```

   - Tick **Done flag**: `_SUCCESS`
   - Keep **Same frequency / start / timezone** ticked, **Instance** on **Default**
6. **Save** and **Submit**

</div>
</div>

---

# 4.3 The schedule (screenshot)

<img src="/images/4_3_hive_coordinator.png" class="rounded shadow mt-2 max-h-96 mx-auto" />

Hue creates the dataset for you and puts `${nameNode}` in front of the path (`Will convert to ...`).

---

# 4.4 coordinator.xml with a dataset

New compared with the time-based one: `<datasets>`, `<input-events>`, one more property.

<style>
.slidev-code { font-size: 0.5rem !important; line-height: 0.865rem !important; }
</style>

<div style="position:relative;width:868px;height:410px;margin-top:0px">
<div style="position:absolute;left:0;top:0;width:540px">

```xml
<coordinator-app name="on-landing-<your_user>"
  frequency="0 0 * * *"
  start="${start_date}" end="${end_date}" timezone="Europe/Berlin"
  xmlns="uri:oozie:coordinator:0.2">
  <datasets>
    <dataset name="landing_dir" frequency="${coord:days(1)}"
             initial-instance="${start_date}" timezone="Europe/Berlin">
      <uri-template>${nameNode}/user/<your_user>/oozie_lab/landing</uri-template>
      <done-flag>_SUCCESS</done-flag>
    </dataset>
  </datasets>
  <input-events>
    <data-in name="landing_dir" dataset="landing_dir">
      <instance>${coord:current(0)}</instance>
    </data-in>
  </input-events>
  <action>
    <workflow>
      <app-path>${wf_application_path}</app-path>
      <configuration>
        <property><name>landing_dir</name>
                  <value>${coord:dataIn('landing_dir')}</value></property>
        <!-- Hue adds: wf_date (yyyyMMdd), oozie.use.system.libpath, start_date, end_date -->
      </configuration>
    </workflow>
  </action>
</coordinator-app>
```

</div>
<svg style="position:absolute;left:0;top:0;pointer-events:none" width="868" height="410" viewBox="0 0 868 410">
<rect x="6" y="21.8" width="528" height="29.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="36.7" x2="576" y2="67.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="77.2" width="528" height="43.5" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="99.0" x2="576" y2="129.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="118.7" width="528" height="15.8" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="126.6" x2="576" y2="191.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="160.2" width="528" height="71.2" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="195.8" x2="576" y2="253.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="284.8" width="528" height="29.7" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="299.6" x2="576" y2="315.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
<rect x="6" y="312.5" width="528" height="15.8" rx="2" fill="none" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 2"/>
<line x1="534" y1="320.4" x2="576" y2="377.0" stroke="#3b82f6" stroke-width="1" stroke-dasharray="1 3"/>
</svg>
<table style="position:absolute;left:576px;top:0;width:292px;font-size:0.66rem;line-height:1.05rem;border-collapse:collapse;table-layout:fixed">
<thead><tr style="height:36px"><th style="width:84px;padding:0 6px">Part</th><th style="padding:0 6px">Meaning</th></tr></thead>
<tbody>
<tr style="height:62px"><td style="width:84px;padding:0 6px;height:62px;line-height:1.05rem">Schedule</td><td style="padding:0 6px;height:62px;line-height:1.05rem"><code>frequency</code>: one action per day; <code>start</code>, <code>end</code>: the window</td></tr>
<tr style="height:62px"><td style="width:84px;padding:0 6px;height:62px;line-height:1.05rem">Dataset</td><td style="padding:0 6px;height:62px;line-height:1.05rem"><b>Where</b> the data lives. No date in the path: same folder every day. <code>frequency</code> is <code>${coord:days(1)}</code></td></tr>
<tr style="height:62px"><td style="width:84px;padding:0 6px;height:62px;line-height:1.05rem">Done flag</td><td style="padding:0 6px;height:62px;line-height:1.05rem">The file that marks a dataset instance as complete</td></tr>
<tr style="height:62px"><td style="width:84px;padding:0 6px;height:62px;line-height:1.05rem">Input event</td><td style="padding:0 6px;height:62px;line-height:1.05rem">The action needs the instance of its own nominal time: <code>coord:current(0)</code></td></tr>
<tr style="height:62px"><td style="width:84px;padding:0 6px;height:62px;line-height:1.05rem">Property</td><td style="padding:0 6px;height:62px;line-height:1.05rem"><code>coord:dataIn(...)</code> is the full path of the instance: how the folder reaches <code>LOAD DATA</code></td></tr>
<tr style="height:62px"><td style="width:84px;padding:0 6px;height:62px;line-height:1.05rem">Added by Hue</td><td style="padding:0 6px;height:62px;line-height:1.05rem">Other properties, e.g. <code>wf_date</code> in the format <code>yyyyMMdd</code></td></tr>
</tbody>
</table>
</div>

---

# 4.5 Let the data arrive: waiting

In the Job Browser open **Schedules** and your coordinator. All actions are **WAITING**. The column `missingDependencies` shows what Oozie waits for:

```text
.../oozie_lab/landing/_SUCCESS
```

<img src="/images/4_5_coordinator_waiting.png" class="rounded shadow w-full mt-2" />

---

# 4.5 Let the data arrive: copy the file

<div class="text-sm">

In **Storage Browser**:

1. Open `/user/<your_user>/oozie_lab` and create the folder `landing`.
2. Go to the workshop data folder (or the root your trainer named):

```text
/2026_cdp_workshop/data/grid_measurements
```

3. Select `sample-grid-measurements.csv`, **Actions → Copy**, target the `landing` folder.

The actions keep waiting: the flag is still missing.

</div>

<img src="/images/4_5_copy_file_to_landing.png" class="rounded shadow w-full mt-2" />

---

# 4.5 Let the data arrive: the flag

<div class="text-sm">

1. In the `landing` folder create an **empty** file named:

```text
_SUCCESS
```

2. Refresh the coordinator. The first action turns **SUCCEEDED** and has started your workflow.
3. The other actions stay **WAITING**: the Hive job moved the files, and the flag with them.

</div>

<img src="/images/4_5_coordinator_landing_first_success.png" class="rounded shadow w-full mt-2" />

---

# 4.5 The result

In **Editor → Hive**:

```sql
SHOW PARTITIONS ${ws_user}.landing_meter;
SELECT dt, COUNT(*) FROM ${ws_user}.landing_meter GROUP BY dt;
```

<img src="/images/4_5_partition_and_row_count.png" class="rounded shadow max-h-44 mx-auto mt-2" />


---
layout: section
---

# 5. Clean up

---

# 5. Clean up

1. In the Job Browser **kill** your running coordinators: `every-5-min-<your_user>` and `on-landing-<your_user>`.
2. In **Editor → Hive** (this also deletes the data because of `external.table.purge`):

```sql
DROP TABLE ${ws_user}.landing_meter;
```

3. Optional: Storage Browser, `/user/<your_user>/oozie_lab`, select, **Delete** (with **Skip Trash**).
4. Workflows and schedules stay in your Hue documents; delete them from the editors if you like.

---

# Self-check

You can answer yes to all of these:

- I can name the three kinds of jobs in the Job Browser.
- I found `workflow.xml` and `coordinator.xml` and can say which UI field produced which element.
- I know what a kill node is and saw a workflow end as **KILLED**.
- I can explain frequency, nominal time and catch-up.
- I can explain dataset, done-flag and input event.
- I found the launcher of an action on YARN or in its log.

---

# Stretch: fork and join

1. Copy the workflow (**Save as**):

```text
fork-wf-<your_user>
```

2. Drag a **Fork** so that `say_hello` and a second shell action `say_bye` (command `echo`, argument `bye`) run in parallel. Hue adds the matching **Join**.
3. Save and submit. In the Job Browser both actions run at the same time.
4. In the XML find `<fork>` with two `<path start="..."/>` elements and the `<join>` node.


---

# What Hue generated, and what it did not

Reading the XML shows what the UI can and cannot do. In the advanced Oozie module you write the same files by hand and add what the editors do not offer:

- `hive2` and `spark3` actions with the **credential** a Kerberos cluster needs
- **Decision** nodes with a named failure path
- **Rerun** of only the failed actions
- Applications kept in **Git** and deployed with a script, instead of folders generated by Hue

---
layout: end
---

# Thank you

Questions?
