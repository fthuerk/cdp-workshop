# Spark via Livy hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. You need two terminals on the edge node (one for `curl`, one for `hdfs` and `yarn` commands). Section 6 additionally needs a terminal and a browser on **your own laptop**.

The lab has three parts:

| Part | Sections | Client | Style |
|------|----------|--------|-------|
| **A. Interactive session** | 0–4 | `curl` | You open a Spark session through REST and send it statements one by one |
| **B. Batch** | 5 | `curl` | You hand Livy a finished script (like `spark-submit`) and follow it without a session |
| **C. Jupyter on your laptop** | 6 | Jupyter + `sparkmagic` | The same session idea, with notebook cells instead of `curl` |

Set your identity and paths once. `WORKSHOP_USER` is the short name you use with `kinit`; you need the Kerberos ticket for the `hdfs` and `yarn` commands. `LIVY_URL` is the Livy address behind the Knox gateway from your handout, without a trailing slash. `LAB_TMP` is a private folder for the request files you create. `LIVY_LAB` holds the shared batch script on HDFS.
```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export WORKSHOP_HOME="/user/${WORKSHOP_USER}"   # your HDFS home; any folder you may write to works
export LIVY_URL="<livy-url-from-your-handout>"
export LIVY_LAB="${WORKSHOP_ROOT}/09-livy"
export LAB_TMP="/tmp/livy-lab-${WORKSHOP_USER}"
```

**Request files.** Livy takes JSON. You write the request bodies yourself with `vim` (open the file, press `i`, type or paste the content, press `Esc`, then `:wq`). The file contents in this lab contain two placeholders you replace with your own values: `<your_user>` (your `WORKSHOP_USER`) and the workshop path `/2026_cdp_workshop` (adjust if yours differs). In `vim`, one command replaces all occurrences: `:%s/<your_user>/alice/g` (use your own name). Check a file for valid JSON with `jq . < "${LAB_TMP}/<file>"`.

## What is Livy?

In the Spark lab you started Spark **from a shell on the edge node** (`pyspark3`, `spark-submit`). That needs a Spark client, the cluster configuration, and a Kerberos ticket on the machine where you work. **Apache Livy** removes that requirement: it is a small server next to the cluster that starts Spark applications on YARN **on your behalf** and exposes them as a **REST API** over HTTPS.

- The **Knox gateway** sits in front of Livy. You log in with your **LDAP username and password** (HTTP Basic authentication over TLS). You do not need `kinit`, a Spark installation, or cluster config files on the machine that calls Livy.
- Livy runs the Spark application **as you** (impersonation), so files you write belong to `/user/${WORKSHOP_USER}` and Ranger policies apply to you as usual.
- Livy knows two kinds of work:

| | Livy **session** | Livy **batch** |
|---|---|---|
| Equivalent | `pyspark3` shell | `spark-submit` |
| REST path | `/sessions`, `/sessions/<id>/statements` | `/batches` |
| You send | Code snippets (**statements**), one after another | A finished script on HDFS plus arguments |
| State | Variables survive between statements | None; the application ends when the script ends |
| Ends | When you `DELETE` it, or after an idle timeout | By itself |

Every Livy session or batch is an ordinary **Spark application on YARN**. You can see it with `yarn application -list` and open its Spark UI like any other.

---

# Part A — Interactive session with `curl`

## 0. Orient — authenticate and talk to Livy

**Goal:** Prove that your LDAP login works against the Livy endpoint and see what is already running.

Livy answers JSON over HTTPS, and every call needs your LDAP credentials. Ask for the password once; the prompt does not echo what you type. It stays only in this shell variable and not in your shell history:

```bash
# Private folder for your request files (mode 700), then your LDAP password
mkdir -p -m 700 "${LAB_TMP}"
read -rsp "LDAP password for ${WORKSHOP_USER}: " LDAP_PASSWORD; echo
```

A `curl` call to Livy has these parts: `-s` (no progress bar), `-u` (user and password for HTTP Basic authentication, checked by Knox), the URL, and for `POST` and `DELETE` also `-X <method>`, the header `Content-Type: application/json` (Livy only accepts JSON), and the header `X-Requested-By` (Livy rejects `POST`/`DELETE` calls without it as a protection against cross-site requests). The password is part of the command line while `curl` runs, so other users of the edge node could see it in the process list for a moment — acceptable for this workshop, not for production. If your handout names a CA certificate for Knox, add `--cacert <path-to-ca.pem>` to every call.

First check only the HTTP status of a harmless call. `200` means Knox accepted your login and Livy answered:

```bash
# -o /dev/null drops the body, -w prints the status code
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" -o /dev/null -w '%{http_code}\n' "${LIVY_URL}/sessions"
```

You should see `200`. A `401` means a wrong user or password, a `403` means your user may not use the Livy service (see [troubleshooting.md](troubleshooting.md)). Now look at the content. `jq .` pretty-prints and colors the JSON:

```bash
# List all sessions and batches that Livy currently knows
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions" | jq .
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/batches" | jq .
```

The answer has the form `{"from": 0, "total": N, "sessions": [...]}`. Livy is shared: sessions of other participants may already be listed. Look at one entry if there is any: `id`, `name`, `state`, `appId`, and `owner` tell you who runs what.

**Check question:** You never ran `kinit` for these calls. How does Livy know which user the Spark application must run as, and which identity will own the files it writes to HDFS?

---

## 1. Open an interactive session

**Goal:** Start a PySpark session through the REST API and find it as an application on YARN.

A session is created with a `POST` to `/sessions`. The body describes what you want. Create the request file with `vim`:

```bash
vim "${LAB_TMP}/session.json"
```

Content of the file (replace `<your_user>`):

```json
{
  "kind": "pyspark",
  "name": "livy-lab-<your_user>",
  "driverMemory": "1g",
  "executorMemory": "1g",
  "executorCores": 1,
  "numExecutors": 1,
  "conf": {"spark.sql.catalogImplementation": "hive"}
}
```

`kind: pyspark` selects Python. The memory and core values are the same resources you would pass to `spark-submit`. `conf` hands arbitrary Spark properties to the application; this one makes the session use the Hive Metastore, so `spark.sql` sees the Hive databases. The `name` must be **unique on the Livy server**, so it contains your user name.

Send it. The answer returns at once with the new session in state `starting`: Livy has only *accepted* your request, the Spark application is still being launched on YARN:

```bash
# Create the session; note the "id" in the answer
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" \
  -H "Content-Type: application/json" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X POST -d @"${LAB_TMP}/session.json" "${LIVY_URL}/sessions" | jq .
```

Remember the id for all later calls and ask for the state until it is `idle` (ready for statements). This usually takes 20–60 seconds; repeat the second command:

```bash
# Replace the placeholder with the id from the answer
export SESSION_ID=<id-from-the-answer>
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/state"
```

You will see `starting`, then `idle`. Other states you may meet: `busy` (a statement is running), `shutting_down`, `error`, `dead`.

Read the full session description. Note `owner` and `proxyUser`, and the `appId` of the YARN application behind your session:

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}" | jq .
```

Now switch to the **second terminal** (same user, valid ticket) and look at the same application from the YARN side:

```bash
# Replace the placeholder with the appId from the session description
yarn application -list -appStates RUNNING -appTypes SPARK
yarn application -status "<application-id>"
```

You should see your application with the name `livy-lab-<your_user>`, type `SPARK`, and state `RUNNING`. In the ResourceManager UI (URL from your handout), open the application and note the **Spark UI** link — the same stages and tasks view as in the Spark lab. The session description from Livy contains it too, under `appInfo`.

**Check question:** Livy itself is a small server. Which process holds your Spark driver — Livy, the edge node, or a YARN container? How can you tell from `yarn application -status`?

---

## 2. Send statements

**Goal:** Run code in your session, read the results, and see what happens on errors.

Your session accepts **statements**: snippets of code that Livy executes in the running PySpark shell. The code is a JSON string, so line breaks inside it are written as `\n`. Start with the smallest possible statement, typed directly on the command line:

```bash
# POST one statement; the answer has the statement "id" (0 for the first one) and state "waiting" or "running"
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" \
  -H "Content-Type: application/json" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X POST -d '{"code": "1 + 1"}' "${LIVY_URL}/sessions/${SESSION_ID}/statements" | jq .
```

A statement is **asynchronous**: you get an id and ask for the result. Statement ids count up per session (0, 1, 2, …). Repeat until `state` is `available`:

```bash
# Replace the placeholder with the statement id
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/statements/<statement-id>" | jq .
```

Look at `output`: `status` is `ok` and `data` holds the result as `text/plain` — here `2`. Longer outputs contain `\n` for line breaks. If you want them as real lines, this one-liner prints only the text; use it as a suffix instead of `jq .` whenever you like:

```bash
# Suffix for the statement result: print only output.data["text/plain"]
| jq -r '.output.data["text/plain"]'
```

From now on every statement lives in a file. Use **single quotes** for strings inside the Python code, so you do not have to escape the double quotes of JSON. First ask the session where it runs and who it is:

```bash
vim "${LAB_TMP}/s2a.json"
```

```json
{"code": "import getpass, os, socket\nprint('host :', socket.gethostname())\nprint('user :', getpass.getuser())\nprint('WORKSHOP_USER in environment:', os.environ.get('WORKSHOP_USER'))\nprint('Spark:', spark.version, '| app:', sc.applicationId)"}
```

```bash
# Send it (note the id), then fetch the result with the statement id
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" \
  -H "Content-Type: application/json" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X POST -d @"${LAB_TMP}/s2a.json" "${LIVY_URL}/sessions/${SESSION_ID}/statements" | jq .
```

Compare the result with your edge node:

```bash
hostname
echo "${WORKSHOP_USER}"
```

The host is a cluster node, not your edge node. The user is **you** (Livy impersonation). `WORKSHOP_USER` is **not** set: your shell exports do not exist in the Spark driver, so request files contain real paths and names, as you saw in the placeholders.

The session already has a `SparkSession` called `spark` and a `SparkContext` called `sc`, exactly like `pyspark3`. Build the small DataFrame from the Spark lab and show it. `show()` is an action; the table comes back as text in the result:

```bash
vim "${LAB_TMP}/s2b.json"
```

```json
{"code": "from pyspark.sql import functions as F\nrows = [('TS-101', 42.5, 63), ('TS-102', 39.0, 58), ('TS-103', 51.2, 71)]\ndf = spark.createDataFrame(rows, ['station_id', 'active_power_kw', 'load_pct'])\ndf.show()"}
```

Send it with the same `POST` command as before (change the file name) and fetch the result. You should see the three stations as a text table.

**Lazy evaluation** works as in the shell: a transformation returns immediately, only an action starts Spark jobs. The variable `df` from the previous statement is still there, because the session keeps its state:

```bash
vim "${LAB_TMP}/s2c.json"
```

```json
{"code": "df_flag = df.withColumn('status', F.when(F.col('load_pct') >= 70, 'HIGH').otherwise('NORMAL'))\ndf_flag.orderBy(F.col('active_power_kw').desc()).show()"}
```

Send it and read the result: the list is sorted by power, and `TS-103` is `HIGH`. Now make a mistake on purpose — select a column that does not exist:

```bash
vim "${LAB_TMP}/s2d.json"
```

```json
{"code": "df.select('no_such_column').show()"}
```

Send it and read the result. You should see `"status": "error"` with `ename` `AnalysisException`. The REST call itself succeeded; the error is part of the statement result. Check that the session survived:

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/state"
```

It is back to `idle`. List all statements of the session with `curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/statements" | jq .` and find the failed one.

**Check question:** What is the difference between a statement in state `error` and a session in state `dead`? Which of the two do you restart, and what do you lose?

---

## 3. Run the pipeline in the session

**Goal:** Read the workshop CSVs, cleanse and join them, and write curated Parquet — the same result as in the Spark lab, driven through Livy.

Three statements, one file each. The driver does not see your shell variables, so the files contain the real paths: replace `/2026_cdp_workshop` if yours differs and `<your_user>` in the last file. The lines are long on purpose — each file is one JSON string, `\n` separates the Python lines. First read the meter and weather CSVs with explicit schemas (CSV fields map by position, so the first field is named `ts_utc`):

```bash
vim "${LAB_TMP}/s3a.json"
```

```json
{"code": "from pyspark.sql import functions as F\nmeter = spark.read.option('header', True).schema('ts_utc STRING, station_id STRING, device_id STRING, phase STRING, active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE, current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE, transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, comm_status STRING').csv('/2026_cdp_workshop/data/grid_measurements/sample-grid-measurements.csv').withColumn('ts_utc', F.to_timestamp(F.col('ts_utc')))\nweather = spark.read.option('header', True).schema('ts_utc STRING, weather_station_id STRING, station_name STRING, temperature_c DOUBLE, relative_humidity_pct INT, wind_speed_mps DOUBLE, precipitation_mm DOUBLE, pressure_hpa DOUBLE, weather_quality STRING').csv('/2026_cdp_workshop/data/operator_weather/sample-operator-weather.csv').withColumn('ts_utc', F.to_timestamp(F.col('ts_utc')))\nprint('meter rows:', meter.count(), '| weather rows:', weather.count())"}
```

Send it as in section 2 and read the result. You should see **15** meter rows and **10** weather rows. Next cleanse the readings and aggregate per station and hour. This statement uses `meter` from the previous one — you do not read the file again:

```bash
vim "${LAB_TMP}/s3b.json"
```

```json
{"code": "meter_ok = meter.filter(F.col('quality_flag') == 'OK').withColumn('event_code', F.when(F.trim(F.col('event_code')) == '', F.lit(None)).otherwise(F.col('event_code'))).dropDuplicates(['ts_utc', 'station_id', 'device_id', 'phase'])\nprint('cleansed:', meter_ok.count(), '| rejected:', meter.count() - meter_ok.count())\nmeter_ok.withColumn('hour_utc', F.date_trunc('hour', F.col('ts_utc'))).groupBy('station_id', 'hour_utc').agg(F.avg('active_power_kw').alias('avg_power_kw'), F.max('transformer_load_pct').alias('max_load_pct')).orderBy('station_id', 'hour_utc').show(truncate=False)"}
```

You should see **12** cleansed and **3** rejected rows, then two hour buckets (08:00 and 09:00 UTC) for each of the three stations. Finally join weather on the timestamp, add the hourly market price, and write the result to your HDFS home (replace `<your_user>`):

```bash
vim "${LAB_TMP}/s3c.json"
```

```json
{"code": "prices = spark.read.option('header', True).schema('price_start STRING, price_end STRING, market STRING, price_eur_mwh DOUBLE, price_ct_kwh DOUBLE, currency STRING').csv('/2026_cdp_workshop/data/awattar/sample-awattar-prices.csv').withColumn('price_hour', F.date_trunc('hour', F.to_timestamp(F.col('price_start'))))\ncurated = meter_ok.join(weather, ['ts_utc'], 'inner').withColumn('price_hour', F.date_trunc('hour', F.col('ts_utc'))).join(prices.select('price_hour', 'price_eur_mwh', 'market'), ['price_hour'], 'left').drop('price_hour')\nprint('curated rows:', curated.count())\ncurated.write.mode('overwrite').partitionBy('station_id').parquet('/user/<your_user>/livy-curated')"}
```

You should see **24** curated rows (12 meter rows × 2 weather stations per timestamp). In the second terminal, inspect what the session wrote:

```bash
# One directory per station, plus _SUCCESS
hdfs dfs -ls "${WORKSHOP_HOME}/livy-curated"
hdfs dfs -du -s -h "${WORKSHOP_HOME}/livy-curated"
```

The files belong to **you**, not to a service user — the proof that Livy runs Spark as your identity.

**Check question:** The session read `meter` once and used it in two later statements. What would be different if you had sent each statement to a **new** session? And what is the price of keeping a session open?

---

## 4. Session state and lifecycle

**Goal:** See that a session keeps its variables, read its log, and close it cleanly so it does not hold cluster resources.

All your variables are still alive in the driver. A new statement can use them without reading any file:

```bash
vim "${LAB_TMP}/s4a.json"
```

```json
{"code": "curated.groupBy('station_id').count().orderBy('station_id').show()"}
```

Send it and read the result. You should see **8** rows for each of the three stations. Livy also keeps a log for the session. It contains the output of the launch (YARN submission), **not** your `print` output — that is in the statement results (and, after the end, in `yarn logs`):

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/log?from=0&size=15" | jq .
```

A session stays alive until you delete it or Livy's idle timeout removes it (typically one hour). A forgotten session holds its YARN containers the whole time. Close yours with `DELETE`:

```bash
# Delete the session; the answer is {"msg": "deleted"}
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X DELETE "${LIVY_URL}/sessions/${SESSION_ID}"
```

Prove that the session is gone — in Livy and on YARN (second terminal):

```bash
# Livy no longer finds the session
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/state"
```

```bash
# Your application is not RUNNING any more
yarn application -list -appStates RUNNING -appTypes SPARK
yarn application -list -appStates FINISHED,KILLED -appTypes SPARK | tail -5
```

You should see an error message from Livy (session not found) and your application among the finished or killed ones. The Parquet files in `${WORKSHOP_HOME}/livy-curated` stay: only the **session** and its variables are gone, not what you wrote to HDFS.

**Check question:** After the `DELETE`, what happened to the variables `meter` and `curated`? What do you have to do to continue the work tomorrow — and how does a Livy **batch** (next part) solve that?

---

# Part B — Batch

## 5. Batch — a script on HDFS

**Goal:** Run the shared PySpark script as a Livy batch and follow it without opening a session.

A batch is the REST version of `spark-submit`: you name a script and its arguments, and the application ends by itself. Admin setup placed `spark_cleanse_join.py` under `${LIVY_LAB}/assets/`. Livy reads the script from HDFS and starts the application as you. The four `args` are the three inputs and the output path, exactly as on the command line in the Spark lab:

```bash
vim "${LAB_TMP}/batch.json"
```

```json
{
  "file": "hdfs:///2026_cdp_workshop/09-livy/assets/spark_cleanse_join.py",
  "name": "livy-batch-<your_user>",
  "args": [
    "/2026_cdp_workshop/data/grid_measurements/sample-grid-measurements.csv",
    "/2026_cdp_workshop/data/operator_weather/sample-operator-weather.csv",
    "/2026_cdp_workshop/data/awattar/sample-awattar-prices.csv",
    "/user/<your_user>/livy-batch-curated"
  ]
}
```

```bash
# Submit; note the "id" in the answer (batch ids are separate from session ids)
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" \
  -H "Content-Type: application/json" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X POST -d @"${LAB_TMP}/batch.json" "${LIVY_URL}/batches" | jq .
```

Follow the batch. States are `starting`, `running`, then `success` (or `dead` on failure). Repeat the state call every few seconds:

```bash
# Replace the placeholder with the id from the answer
export BATCH_ID=<id-from-the-answer>
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/batches/${BATCH_ID}/state"
```

The batch description gives the YARN `appId`; the batch log shows what Livy's `spark-submit` printed while it watched the application:

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/batches/${BATCH_ID}" | jq .
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/batches/${BATCH_ID}/log?from=0&size=20" | jq .
```

When the state is `success`, check the result in the second terminal:

```bash
hdfs dfs -ls "${WORKSHOP_HOME}/livy-batch-curated"
yarn application -list -appStates FINISHED -appTypes SPARK | tail -5
```

You should see `_SUCCESS` and one directory per station, with the same content (**24** rows) as the session result of section 3. Livy keeps the finished batch in its list for a while; remove it:

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X DELETE "${LIVY_URL}/batches/${BATCH_ID}"
```

| | Livy session | Livy batch | `spark-submit` (Spark lab) |
|---|---|---|---|
| Started from | Any machine with HTTPS access | Any machine with HTTPS access | Edge node with Spark client and ticket |
| Authentication | LDAP via Knox | LDAP via Knox | Kerberos |
| Code | Statements, interactive | Script on HDFS | Script, local or HDFS |
| Where the driver runs | YARN container | YARN container | Client or cluster mode (you choose) |
| Typical use | Exploration, notebooks | Scheduled or triggered pipelines | Pipelines on the edge node, Oozie |

**Check question:** A scheduler in another system (outside the cluster network zone) has to start the cleanse job every night. Why is a Livy batch a better fit than a Livy session here? Where do you find the `print` output of the script?

---

# Part C — Jupyter on your laptop

## 6. A local Jupyter notebook with a Livy session

**Goal:** Work interactively from a notebook on your own laptop; the Spark code runs on the cluster, and only small results come back.

So far `curl` was the client. A notebook is just a friendlier client: **`sparkmagic`** is a Jupyter extension that creates a Livy session for you and sends the code of each `%%spark` cell as a statement — the REST calls you made by hand. Your laptop needs **no Spark installation and no Kerberos**; it only needs HTTPS access to `LIVY_URL` and your LDAP login. Everything in this section runs on **your laptop**, in a new terminal (not on the edge node). It does not change the core lab: `check.sh` does not depend on it.

**6.1 Get the notebooks.** Put the folder `09-basics-livy/lab/notebooks` from the workshop repository on your laptop (clone the repository, or copy the folder from the edge node with `scp -r`; the location is in your handout). It contains two notebooks and two helper files.

| File | Purpose |
|------|---------|
| `livy_sparkmagic.ipynb` | The main notebook: `sparkmagic` magics, the pipeline of section 3, a result pulled back into pandas |
| `livy_rest_requests.ipynb` | Fallback without `sparkmagic`: the REST calls of sections 1–4 in Python with `requests` |
| `requirements.txt` | Python packages for both notebooks (includes `pyspark==3.5.4`, only for code completion and highlighting on your laptop; Spark itself runs on the cluster) |
| `sparkmagic_config.template.json` | Settings for `sparkmagic` (no credentials) |

**6.2 Install.** Use a Python virtual environment (Python 3.12) so that nothing else on your laptop is touched. Choose **one** of the two ways:

```bash
# Option A: pip + venv (run in the notebooks folder on your laptop)
python3.12 -m venv livy-venv
source livy-venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

```bash
# Option B: conda (run in the notebooks folder on your laptop)
conda create -n livy-lab python=3.12 -y
conda activate livy-lab
pip install -r requirements.txt   # sparkmagic is not on the default conda channel; pip inside the env is fine
```

**6.3 Configure.** `sparkmagic` reads its settings (timeouts, headers) from `~/.sparkmagic/config.json`. Copy the contents of [`notebooks/sparkmagic_config.template.json`](notebooks/sparkmagic_config.template.json) into that file (create the folder `~/.sparkmagic` and the file if they do not exist; if you already have a config there, keep a backup first). The template has no password in it: the notebook asks for it when you run it.

Then start Jupyter. If the Knox certificate comes from an internal CA, set the CA file from your handout first:

```bash
# Only if your handout names a CA file
export REQUESTS_CA_BUNDLE="<path-to-ca.pem>"
jupyter lab
```

**6.4 Run the notebook.** Open `livy_sparkmagic.ipynb` in the browser and run it cell by cell. The first cell asks for the Livy URL, your user name, and your LDAP password. Read the markdown cells before each step; the table at the top of the notebook explains every flag (`-s`, `-c`, `-o`, `-m`, `-n`, `-t`, `-i`, …). What the notebook shows:

| Step | What you learn |
|------|----------------|
| `%load_ext sparkmagic.magics`, `%spark add` | The magic opens a Livy session in the background — the `POST /sessions` of section 1 |
| `%spark info` | Session id, YARN application id, and the Spark UI link of **your** session |
| `%%spark` cells | The cell code is the statement body; `spark` is the session's `SparkSession`. All cells share one session, so the pipeline is split into small cells, one per step |
| Paths on the cluster | Notebook variables live on your laptop only; the first `%%spark` cell sets `workshop_root` and `workshop_home` inside the session |
| `%%spark -c sql` | A cell that is a Spark SQL query; the result is shown as a table |
| `%%spark -o hourly` | Copies the (small!) DataFrame `hourly` **to your laptop** as a pandas DataFrame, so you can plot it locally |
| `%spark delete`, `%spark cleanup` | Closes the session — the `DELETE` of section 4 |

While the notebook session is open, look at it from the edge node (second terminal) and confirm that your notebook is a normal Spark application on YARN:

```bash
yarn application -list -appStates RUNNING -appTypes SPARK
```

At the end of the notebook the pipeline writes to `${WORKSHOP_HOME}/livy-nb-curated`; check it with `hdfs dfs -ls` from the edge node.

**If `sparkmagic` does not install** (blocked packages, unsupported Python version), run `livy_rest_requests.ipynb` instead. It needs only `requests`, shows the same REST calls you typed with `curl`, wrapped in a small Python class, and runs the same pipeline.

**Check question:** You close the notebook browser tab but never run `%spark delete`. Does the Livy session stop? Where do you look for it, and who frees its resources?

---

## 7. Optional — failure signals and when to use Livy

**Goal:** Provoke typical Livy failures and learn to tell them apart.

**Wrong password** — a `401` from Knox before Livy is even involved (the password in the call is deliberately wrong):

```bash
curl -s -u "${WORKSHOP_USER}:wrong-password" -o /dev/null -w '%{http_code}\n' "${LIVY_URL}/sessions"
```

**Unknown session** — Livy answers with a message instead of JSON data:

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/999999/state"
```

**Impossible resources** — request an executor that no YARN node can host. The session ends in `dead` or `error` instead of `idle`; read the reason in the Livy session log. The body is short enough to type on the command line:

```bash
# Request with a huge executor memory; note the id in the answer
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" \
  -H "Content-Type: application/json" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X POST -d '{"kind": "pyspark", "executorMemory": "512g"}' "${LIVY_URL}/sessions" | jq .
```

```bash
# Replace the placeholder with the id from the answer; wait a minute, then read state and log
export BIG_ID=<id-from-the-answer>
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${BIG_ID}/state"
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${BIG_ID}/log?from=0&size=40" | jq .
```

```bash
# Clean up
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" -H "X-Requested-By: ${WORKSHOP_USER}" \
  -X DELETE "${LIVY_URL}/sessions/${BIG_ID}"
```

**Wrong input path** — in a new session (section 1), a statement `spark.read.csv('/no/such/path').count()` returns `status: error` with `AnalysisException` / `Path does not exist`, and the session stays `idle`.

**Livy, `spark-submit`, or the shell?** Use the table as a rule of thumb:

| Need | Choose |
|------|--------|
| Quick exploration on the edge node | `pyspark3` |
| Notebook or tool on a machine without a Spark client | Livy session (sparkmagic, or a script with REST) |
| Pipeline started by a scheduler or an application outside the cluster network zone | Livy batch |
| Pipeline run by Oozie or on the edge node | `spark-submit` |
| Long, expensive pipeline that must not depend on one client | Batch (cluster mode) — never a session you keep alive by hand |

---

## Stretch (optional)

- Open a session with `"conf": {"spark.sql.shuffle.partitions": "2"}` and an `"executorMemory"` of `"2g"`; check with `spark.conf.get('spark.sql.shuffle.partitions')` and in the Spark UI Environment tab.  
- Submit the batch of section 5 with an **output path you may not write to** (for example below another user's home) and find the reason in `yarn logs -applicationId <appId>`; compare with the Livy batch log.  
- In the notebook, use `%%configure -f` with a JSON body to change the executor memory and restart your Livy session; check the new value in the Spark UI.  
- Write a bash loop that polls `/batches/${BATCH_ID}/state` every 5 seconds and stops on `success` or `dead` — the beginning of a scheduler integration.

---

## Self-check

From the repo on the edge node (after you deleted your sessions, with a valid Kerberos ticket). If `LDAP_PASSWORD` is still set in this shell, export it first so the check can also test the Livy login:

```bash
export LDAP_PASSWORD
./09-basics-livy/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
