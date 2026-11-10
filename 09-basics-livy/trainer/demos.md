# Trainer demos — Module 09 Spark via Livy

Optional live-only steps — not required for participants. They need admin access to Cloudera Manager or the Livy and Knox hosts.

## 1. What Livy actually runs (3 min)

While a participant session starts (lab section 1), open the Livy server log in Cloudera Manager (**Livy for Spark 3 → Log Files → Role log**) and find the `spark-submit` command that Livy built: `--proxy-user <participant>`, `--deploy-mode cluster`, the application name, and the memory options from the request. This makes impersonation and "Livy is a launcher" tangible.

## 2. Knox audit (2 min)

In the Knox host log directory open `gateway-audit.log` and find the `LIVY` requests with the participant's user name and the HTTP status. Show a `401` from a wrong password: it appears in Knox **before** Livy sees anything.

## 3. Livy web UI (optional, 2 min)

If the Livy UI is reachable (`<livy-host>:<port>/ui`), show the table of sessions and batches of all participants with owner, state, and application id. Click through to the log. Point out that **all** sessions on the server are visible to everyone who can call `GET /sessions` — which is why the lab uses unique names.

## 4. Forgotten session (3 min)

Open a session with the lab request body and do not delete it. On YARN, show the application `RUNNING` with its containers although no statement was sent. Then delete it as admin (`DELETE /sessions/<id>`) and watch the application disappear. Mention `livy.server.session.timeout` and the heartbeat timeout (`heartbeatTimeoutInSecond` in the request) as safety nets.

## 5. Spark UI of a session (2 min)

Send a heavier statement (for example the `s3c.json` pipeline with `repartition(50)` before the join) and open the Spark UI through the ResourceManager proxy while it runs: stages and tasks of an interactive Livy session look exactly like those of `pyspark3`.

## 6. Resource limits (3 min)

Show the lab section 7 request with `"executorMemory": "512g"`: YARN refuses the request at submission, the session goes `dead`, and the reason is in `GET /sessions/<id>/log`. Relate to the YARN module (container limits, queues).

## 7. Hue / other clients (optional)

The same Livy endpoint serves other clients. If your cohort uses Hue, show the Spark notebook in the Hue editor: Hue calls the same `/sessions` and `/statements` endpoints behind the scenes. Do not duplicate the lab — one statement is enough.
