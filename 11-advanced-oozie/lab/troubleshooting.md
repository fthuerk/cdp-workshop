# Oozie lab — troubleshooting

## `oozie: command not found`, or `Oozie URL is not available`

- Use the `oozie` command from your handout (it is on the edge node).
- `echo "${OOZIE_URL}"` must show the URL from your handout. Set it again with `export OOZIE_URL=...` — variables are per terminal.

## `AUTHENTICATION : Could not authenticate`, `Authentication required`, or `401` from the `oozie` command

The Oozie endpoint is behind the Knox gateway and uses your user name and password, not Kerberos.

- Every `oozie` command needs `-auth BASIC -username "${WORKSHOP_USER}" -password "${WORKSHOP_PASSWORD}"`. For `oozie validate` the options go **before** the file name: `oozie validate -auth BASIC -username "${WORKSHOP_USER}" -password "${WORKSHOP_PASSWORD}" workflow.xml`. Behind them, a trailing option is read as a second file and you get `One file must be specified`.
- `echo "${#WORKSHOP_PASSWORD}"` must show a number greater than 0. If it shows 0, run the `read` and `export` lines again (variables are per terminal). A wrong password gives the same error: try `oozie admin -version -auth BASIC -username "${WORKSHOP_USER}" -password "${WORKSHOP_PASSWORD}"`.
- `echo "${OOZIE_URL}"` must show the Knox address from your handout (`https://<knox-host>:8443/gateway/cdp-proxy-api/oozie`).
- `klist` and `kinit` are still needed for `hdfs`, `beeline` and `spark-submit`, but they do not help with this error.

## `javax.net.ssl.SSLHandshakeException` or `PKIX path building failed`

The Oozie URL uses TLS and your client does not trust the certificate. Ask your instructor for the truststore option of your edge node.

## The pasted text in `vim` looks like a staircase

`vim` indents each pasted line again (auto-indent). Press `Esc`, run `:%d` to empty the file, then `:set paste`, press `i`, paste again, press `Esc` and save with `:wq`. Do this for every file with several lines. Paste mode ends when you leave `vim`.

## `oozie validate` or `-run` reports an XML or schema error

- Read the line and column in the message; a missing `>` or a quote that the shell removed is the usual cause.
- When you type `workflow.xml` in `vim`, paste it unchanged: the `${...}` expressions are filled in by Oozie, not by you. In the `.properties` files only the angle-bracket placeholders (`<your_user>`, `<name-node>`, …) are yours to replace; leftover `<...>` in a file is a common cause of errors.
- A `Schema ... not supported` error means the server does not know the version in `xmlns`. Ask your instructor which versions the cluster accepts.

## `-run` says the application path does not exist, or `workflow.xml not found`

- `hdfs dfs -ls "${OOZIE_HDFS}/apps/<name>"` must show `workflow.xml`.
- `oozie.wf.application.path` in your properties file must point to the **folder** (with `hdfs://...`), not to the file.
- Open the properties file and look for an empty value: an unset shell variable (`NAME_NODE`, `OOZIE_HDFS`) at the time you created the file is the usual reason. Set the variable and create the file again.

## A variable such as `${nameNode}` stays unresolved, or the message mentions an EL error

The workflow uses a variable that your properties file does not define. Compare the names in `workflow.xml` (`${...}`) with the left side of the lines in the file. Names are case-sensitive.

## Job ends `KILLED` and the message is empty or unclear

- `oozie job -info <job-id>`: find the action in state `ERROR` or `KILLED` and note its **Ext ID**.
- `yarn logs -applicationId <ext-id>` shows the output of the launcher — the real error is there.
- `oozie job -log <job-id>` shows what the Oozie server did.

## Shell action: `Permission denied` or `command not found`

The script is started from the container's working directory. Use `<exec>hello.sh</exec>` together with `<file>hello.sh#hello.sh</file>`, and start the script with `#!/bin/bash`.

## Hive2 action: `GSS initiate failed` or `Could not open client transport`

- Is `cred="hs2-creds"` on the action and the `credentials` block at the top of the workflow?
- `jdbcURL` and `jdbcPrincipal` come from your handout. The principal needs the real HiveServer2 host name, not `_HOST`, unless your instructor says otherwise.
- Ask your instructor whether the `hive2` credential type is enabled in Oozie.

## Hive2 action: permission denied on a database, table or folder

Oozie runs the action as you. You need the same Hive and HDFS rights as in the Hive lab: your own database and the shared sample data. Try the failing statement in Beeline.

## Spark action: `Spark action is disabled`, class not found, or missing ShareLib

- The action element is `spark3`, not `spark`. The older Spark 2 action is disabled by default.
- The cluster ShareLib must include `spark3` (your instructor checks this before the session). If Spark actions fail with missing ShareLib errors, ask your instructor — fixing ShareLib is not a participant step.
- `oozie.use.system.libpath=true` must be in your properties file (it is in `common.properties`).

## Spark action: `Path does not exist`

Check `weatherDir`: `hdfs dfs -ls` on the value in your properties file. Section 6 breaks this on purpose; repair it with the rerun.

## Section 10: the `csv-to-table` action ends `KILLED` or `ERROR`

- Take the **Ext ID** from `oozie job -info "${WF_ID}"` and read `yarn logs -applicationId <ext-id>`. The Spark application is a second YARN application next to the launcher; its log has the Python error.
- `Path does not exist`: check `csvDir` with `hdfs dfs -ls`. The folder must contain CSV files with a header line.
- Database or table not found, or a GSS error towards the Metastore: `hdfs dfs -ls "${OOZIE_HDFS}/apps/csv-load"` must list `hive-site.xml`, the action needs `cred="hcat-creds"`, and `metastoreUri` and `metastorePrincipal` must be the values from `hive-site.xml`. Ask your instructor whether the `hcat` credential type is enabled in Oozie.
- `Permission denied` on the warehouse folder: you may only create tables in your own database (`database` in `common.properties` must be your user name).

## Section 10: the `load-managed` action ends `KILLED` or `ERROR`

- `GSS initiate failed` or `Could not open client transport`: see the Hive2 action entry above; `jdbcURL` and `jdbcPrincipal` come from `common.properties`.
- `Table not found`: the Spark step has to create the external table first. `extTable` and `database` are used by both steps; the job reads them from the same properties file.
- You changed a file on the edge node and nothing changed in the run: upload it again with `hdfs dfs -put -f`. Oozie runs the copy on HDFS.

## Job stays `RUNNING` and the YARN application stays `ACCEPTED`

The cluster has no free container. Oozie launchers wait for capacity like every other application. Wait a few minutes or ask your instructor; see the YARN lab for how to read the queue.

## Coordinator action stays `WAITING` in section 8

- `oozie job -info "<coordinator-id>@1"` shows **Missing Dependencies**: compare the path with your `hdfs dfs -ls "${OOZIE_HDFS}/landing"`.
- The folder is named with the **UTC** date (`date -u`). Right after midnight UTC the day in the path can differ from your local day.
- The file `_SUCCESS` must exist in the folder. An empty file is fine; a folder named `_SUCCESS` is not.
- Oozie checks about once a minute. Wait before you worry.

## Coordinator: `start` must be before `end`, or no actions appear

`date -u -d` needs GNU `date` (the edge node). The times need the `Z` suffix and the format `2026-11-01T18:05Z`. `echo "${START} ${END}"` shows what you passed.

## Coordinator still `RUNNING` after the lab

Kill it: `oozie job -kill "<coordinator-id>"`. List yours with `oozie jobs -jobtype coordinator -filter "user=${WORKSHOP_USER};status=RUNNING"`.

## `check.sh` fails on a workflow count

`check.sh` looks for finished jobs by **application name**: `hello-wf`, `landing-check-wf` (one `SUCCEEDED` and one `KILLED`), `meter-hive-wf`, `meter-weather-wf`, `meter-daily-wf`, `csv-load-wf`. The section number in the failure message tells you what to redo. Jobs from earlier tries stay in the list; you only need one successful run each.

## Still failing

Ask your instructor. Trainer: see [../trainer/notes.md](../trainer/notes.md) and [../setup/verify.sh](../setup/verify.sh).
