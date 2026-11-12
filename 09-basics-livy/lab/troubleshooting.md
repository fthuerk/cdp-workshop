# Livy lab — troubleshooting

## `401` from the Livy URL (or an empty answer, or `parse error` from `jq`)

Knox rejected the login: wrong user name or LDAP password, or the account is locked after too many attempts.

- Check that `LDAP_PASSWORD` is set in this shell (`[ -n "${LDAP_PASSWORD}" ] && echo set`) and re-enter it with the `read -rsp` command of lab section 0 if you mistyped it. A new terminal has no `LDAP_PASSWORD`.  
- A password with `$`, `"` or a backtick is fine inside the variable, but keep the double quotes around `"${WORKSHOP_USER}:${LDAP_PASSWORD}"` in every call.  
- Use the **LDAP** password (Hue / Knox login), not your Kerberos password if they differ. Check that `WORKSHOP_USER` is exactly your login name.  
- Locked account: ask your instructor.

## `403 Forbidden`

You logged in, but Knox or the Livy service does not accept your user (topology authorization, group membership). Ask your instructor — see the trainer notes for the Knox topology and Livy impersonation settings.

## `404 Not Found` or an HTML page for `${LIVY_URL}/sessions`

The URL is wrong. Compare with your handout: scheme `https`, the Knox host and port, the gateway path and the topology name, **no trailing slash**. If your handout URL ends in `/livy` or `livy_for_spark3`, that part belongs to `LIVY_URL`.

## `curl: (60) SSL certificate problem` / `SSLError` in the notebook

The Knox certificate is signed by a CA your machine does not know.

- `curl`: add `--cacert <path-to-ca.pem>` to the call (CA file from your handout).  
- Notebook: set `export REQUESTS_CA_BUNDLE="<path-to-ca.pem>"` in the terminal **before** `jupyter lab`, then restart the kernel.  
- Do not switch certificate checks off for anything except a throwaway test.

## `curl: (6)` / `(7)` / timeout from the laptop

The laptop cannot reach the Knox host: VPN, proxy, or firewall. Test with `curl -I "${LIVY_URL}"` — any HTTP answer (even 401) proves the path works. On the edge node the same call works, so use `curl` there and ask your instructor about the network path for Jupyter.

## `400` with `Duplicate session name` when creating a session

A session called `livy-lab-<your_user>` already exists (from an earlier try). List sessions, find the one with your name, delete it, and create again:

```bash
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions" | jq .
curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" -H "X-Requested-By: ${WORKSHOP_USER}" -X DELETE "${LIVY_URL}/sessions/<id>"
```

## `SESSION_ID`, `LIVY_URL` or `LAB_TMP` is empty (URL ends in `/sessions//state`, `No such file`)

The variables exist only in the shell where you exported them. In a new terminal repeat the exports from the top of the lab and the `read -rsp` command of section 0 for the password.

## The session stays in `starting`

Livy waits for YARN. Look at the application on the edge node:

```bash
yarn application -list -appStates ACCEPTED,RUNNING -appTypes SPARK
```

`ACCEPTED` for a long time means the queue has no free memory — other participants hold sessions. Delete your unused sessions and wait. If nothing shows up on YARN, read `${LIVY_URL}/sessions/<id>/log` for the reason.

## The session ends as `dead` or `error`

Read the session log (`/sessions/<id>/log?from=0&size=50`). Typical reasons: requested memory above the YARN limit, no permission to submit to the queue, Kerberos or impersonation problem on the server side (then ask your instructor). Delete the dead session and create a new one.

## A statement result shows `"status": "error"`

The REST call worked; your code failed. Read `ename` and `evalue` (for example `AnalysisException`, `NameError`). A `NameError` often means the earlier statement that defined the variable ran in a **different or new** session — variables live only in one session. Send the three statements of section 3 (`s3a.json`, `s3b.json`, `s3c.json`) to the same session, in this order.

## The `POST` of a statement answers with an error instead of an id

The `POST` returned an error instead of a statement: wrong `SESSION_ID`, session already deleted, or the session is not `idle` yet. Check `curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/sessions/${SESSION_ID}/state"`. A `400` with a message about the JSON body means the file is not valid JSON: `jq . < "${LAB_TMP}/<file>"` shows the line.

## `AnalysisException: Path does not exist`

- The statement file must contain the real path: open `"${LAB_TMP}/s3a.json"` in `vim` and check that `/2026_cdp_workshop` matches your `WORKSHOP_ROOT`. Shell variables such as `${WORKSHOP_ROOT}` are **not** expanded inside a file — the driver would see them as text.  
- Check the path on HDFS: `hdfs dfs -ls "${WORKSHOP_ROOT}/data/grid_measurements/"`.  
- If bootstrap never ran, ask your instructor to run `00-setup/admin/bootstrap.sh`.

## Batch ends as `dead`

The batch log in Livy only shows the submission. The real error is in the YARN application log. Take the `appId` from `curl -s -u "${WORKSHOP_USER}:${LDAP_PASSWORD}" "${LIVY_URL}/batches/${BATCH_ID}"` and run `yarn logs -applicationId <appId> | tail -60`. Frequent causes: script path wrong (`file` in `batch.json` must be `hdfs://<WORKSHOP_ROOT>/09-livy/assets/spark_cleanse_join.py` — ask your instructor to run the module setup if the file is missing), output path already exists without overwrite (the script overwrites), `Permission denied` on the output folder.

## `Permission denied` on HDFS write under `/user/...`

Livy runs Spark as `WORKSHOP_USER`; that user must own `${WORKSHOP_HOME}`. Ask your instructor if your home directory is missing or if Livy runs everything as one service user (impersonation off) — then the written files belong to `livy`, which you can see with `hdfs dfs -ls "${WORKSHOP_HOME}"`.

## Jupyter: `pip install` fails, or `No module named sparkmagic.magics`

- Use Python 3.12 in a fresh virtual environment or conda environment (`python --version`); the lab needs `sparkmagic>=0.23` (older versions pin `pandas<2`, which does not install on Python 3.12).  
- Make sure the virtual environment is active (`source livy-venv/bin/activate`) and that you start `jupyter lab` from **that** environment.  
- If installation stays blocked, use `livy_rest_requests.ipynb` — it needs only `requests`.

## Jupyter: `%spark add` hangs, shows `HTTPError 401`, or the session ends in `error`

- 401: wrong user or password in the first cell — rerun it.  
- Hang at `starting`: queue full (see above) or `livy_session_startup_timeout_seconds` in `~/.sparkmagic/config.json` too small — raise it to `300`.  
- `Duplicate session name` is unlikely here: the notebook names the Livy session `<user>-livy-nb-<HHMMSS>` (or `<user>-spark-lab-<HHMMSS>` in module 06), so every start gets a new name. Old notebook sessions pile up, though: list `${LIVY_URL}/sessions`, find yours by `owner` or by the name, delete them.

## Jupyter: `%%spark -o hourly` fails with a conversion error

`-o` copies a **DataFrame** (or a value `sparkmagic` can convert). Check that the cell ends with the variable defined as a DataFrame and that the result is small. Timestamps are cast to strings in the lab notebook for this reason.

## Statement files: `placeholder` left in the file or `NameError: <your_user>`

You did not replace `<your_user>` in the file. Open it in `vim` and run `:%s/<your_user>/yourname/g`, then send the statement again.

## Self-check: row count not 24

- **24 joined rows:** inner join on `ts_utc` only — each of 12 OK meter rows matches two weather stations. Redo section 3 (the cleansing statement must keep only `OK` rows).  
- Missing `_SUCCESS` on `livy-batch-curated`: the batch state must be `success` before you continue; redo section 5.  
- Missing shared script: instructor runs `./09-basics-livy/setup/setup.sh`.  
- `Your session livy-lab-<user> is still open`: delete it as in section 4.
