# Trainer notes — Module 09 Spark via Livy

**Dry-run status:** run once with a participant account before the session. The Knox topology name, the Livy URL path, and the Livy defaults (deploy mode, Hive context, timeouts) differ between CDP versions and installations — verify the points in "Admin checklist" below.

## Suggested timing (~90 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: why a REST gateway for Spark; session vs batch; Knox + LDAP; impersonation. Draw the flow from [deep-dive.md](deep-dive.md) |
| 10–20 | Section 0: password variable, the parts of a `curl` call, first calls (`200`, session list) |
| 20–30 | Section 1: open session, poll `starting` → `idle`, find the application on YARN |
| 30–40 | Section 2: statements as JSON files edited with `vim`, polling by hand, error statement; host and user check |
| 40–50 | Section 3: pipeline in three statements (15/10, 12/3, 24 rows), Parquet in the home |
| 50–55 | Section 4: state survives, log, `DELETE`, YARN check |
| 55–65 | Section 5: batch, state polling, comparison table |
| 65–90 | Section 6: Jupyter on the laptop (install happens before the session if possible) |
| — | Section 7 optional / stretch; `check.sh` |

If time is tight: demo section 5 on the projector and skip section 7. Ask participants to **install the Jupyter environment (6.2) before the workshop** — pip downloads are the usual time sink; the fallback notebook (`requests` only) is the plan B for locked-down laptops.

## Check-question answers

1. **Identity (0):** Knox authenticates the LDAP user and forwards the call to Livy with the user as `doAs`. Livy trusts only the Knox service user as a proxy (`livy.superusers`) and, with impersonation enabled, starts `spark-submit --proxy-user <user>`. The Spark application therefore runs as the participant and the files in HDFS are owned by them. No Kerberos ticket is needed on the caller's side; the Kerberos login of the Livy service itself is hidden behind the gateway.
2. **Where is the driver (1):** In a **YARN container** (Livy deploys in cluster mode on CDP; `livy.spark.deploy-mode=cluster`). `yarn application -status` shows an AM host that is a cluster node, not the Livy host. The section 2 statement (`socket.gethostname()`) confirms it. If your Livy runs in client mode, the driver sits on the Livy server — say so and relate it to the capacity limits of that host.
3. **Statement `error` vs session `dead` (2):** A failed statement is a Python/Spark exception in the user code: the session stays `idle` and all variables stay. A `dead` (or `error`) session means the Spark application itself ended (resources refused, driver crash, killed): all state is lost and you create a new session.
4. **New session per statement (3):** Each session needs 20–60 seconds to start and has empty state — the CSV would be read and cleansed again. The price of an open session is its YARN containers (driver + executors) for the whole time, also when nobody sends statements; forgotten sessions block the shared queue until the idle timeout.
5. **After `DELETE` (4):** The variables are lost with the driver; only files and tables written to HDFS / Metastore stay. A batch is the answer: the logic lives in a versioned script and is started with the same arguments tomorrow.
6. **Scheduler outside the cluster zone (5):** A batch needs one HTTPS call, ends by itself, keeps no containers, and is repeatable from a script; no interactive state has to be kept alive or cleaned up. The `print` output of the script is in the driver's `stdout` in the YARN logs (`yarn logs -applicationId <appId>`), not in the Livy batch log (which only shows the submission).
7. **Closed tab (6):** No. The Livy session and the YARN application keep running until someone sends `DELETE` (`%spark delete`) or Livy's session timeout removes the idle session. Resources are freed by the participant or by the timeout/admin — the same lesson as in section 4.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| Wrong URL / topology | Test the handout URL with `curl -u` before the session. Common form behind Knox on CDP Private Cloud Base: `https://<knox>:<port>/gateway/<topology>/livy_for_spark3`; the topology and the service path differ by installation |
| `400` on `POST` or `DELETE` | The header `X-Requested-By` is missing (Livy CSRF protection). Participants type both `-H` headers in every `POST`/`DELETE` call |
| `Duplicate session name` | Names are unique per Livy server. Participants who restart need to `DELETE` the old session. Admin can list `GET /sessions` and delete leftovers |
| All participants start sessions at once | Each session = driver + executor containers (about 2–3 GB with overhead). Check the queue capacity for N participants, or stagger the start. Sessions stuck in `starting` show as `ACCEPTED` on YARN |
| Session limits | Livy can cap the number of sessions or creation rate (`livy.server.session.max-creation`); `429`/`Rejected` answers mean the cap was hit |
| Variables from the shell missing in the driver | Intended: shows that the driver runs on the cluster. Statement files contain real paths and the user name (placeholder `<your_user>`, replaced in `vim` with `:%s`). A typical mistake is a forgotten placeholder or a left-over `${...}` in a file |
| Script path in batch | `file` must be on HDFS (or in `livy.file.local-dir-whitelist`); a local laptop path is rejected |
| Certificates | Internal CA: participants need the CA file (handout); do not tell them to disable verification |
| Passwords | The lab keeps the password in a shell variable and passes it with `curl -u`, so it is visible in the process list of the shared edge node while `curl` runs. Acceptable for a workshop; mention that production uses tokens or a netrc file. The notebook keeps it in kernel memory only (`getpass`). Remind participants to close terminals / `unset LDAP_PASSWORD` afterwards |
| Long JSON lines in `vim` | The statement files are one-line JSON strings (`\n` between Python lines). Hand out the lines on the projector or in the handout if typing is too slow; `jq . < file` finds typos |
| LDAP lockout | Many wrong attempts lock accounts; tell participants to stop after two 401 answers and ask you |
| `sparkmagic` and Python | Lab uses Python 3.12 with `sparkmagic>=0.23` (pandas 2.x). `sparkmagic 0.21` needs `pandas<2` (Python ≤ 3.11); if a participant has an older sparkmagic pinned → fallback notebook |
| Self-service participants (no admin) | `00-setup/participant/setup.sh` runs this module's setup too; they still need the Livy URL and an LDAP account |

## Admin checklist (before the session)

- **Livy for Spark 3** service installed and running; Knox topology (the one with LDAP authentication) contains the Livy service; `LIVY_URL` from `config.env` works with a workshop account.  
- Livy impersonation on (`livy.impersonation.enabled=true`), Knox user in `livy.superusers`, and `hadoop.proxyuser.livy.*` allows the workshop group.  
- Knox / Livy access: workshop group may use the Livy service (Knox authorization, no Ranger Knox policy denying `livy`).  
- Ranger: same Hive `{USER}` and HDFS policies as module 06 — see [ranger README](../../00-setup/admin/ranger/README.md).  
- Optional: lower `livy.server.session.timeout` (for example 30 min) for the workshop so forgotten sessions disappear.  
- Run `./09-basics-livy/setup/setup.sh`, then `verify.sh` (checks the endpoint answers `401`/`200`).

## Admin

[setup/setup.sh](../setup/setup.sh) uploads `spark_cleanse_join.py` to `${WORKSHOP_ROOT}/09-livy/assets/` and creates `work/` with mode `1777`. [setup/teardown.sh](../setup/teardown.sh) removes the script; it does not delete participant sessions — list and delete leftovers via `GET /sessions` and `DELETE /sessions/<id>`.

## After module

Module 08/11 (Oozie) run the same script with `spark3` actions; module 06 is the same pipeline with the Spark client. A later advanced Spark module can use Livy sessions as the compute backend for notebooks.
