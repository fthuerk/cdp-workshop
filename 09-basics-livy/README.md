# Module 09 — Basics: Spark via Livy

Run the grid monitoring pipeline (smart-meter CSVs cleansed, joined with operator weather and market prices, written as curated Parquet) **without a Spark client on your machine**: you talk to Spark on YARN through the **Apache Livy REST API** behind the Knox gateway — first with `curl`, then from a **Jupyter notebook on your own laptop**.

**Estimated time:** ~90 minutes (core ~65 min, Jupyter on your laptop ~20 min, optional section and stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`) on the edge node — used for `hdfs` and `yarn` commands
- Your **LDAP password** (the same account the Knox gateway and Hue use) and the **Livy URL** from your handout — Livy itself never sees a Kerberos ticket from you
- For the Jupyter part: a laptop with Python 3.9–3.11 that can reach the Knox URL (VPN if required)

## Learning goals

After this module you can:

- Explain what Livy is: a REST service that starts Spark applications on YARN for you, in **session** (interactive) and **batch** (`spark-submit`) form
- Authenticate against Knox with LDAP username and password and call the Livy REST API with `curl`
- Open an interactive session, submit **statements**, read their results, and see that session state survives between statements
- Find the Livy session as a Spark application on YARN and close it cleanly
- Submit the shared PySpark script as a Livy **batch** and follow its state and log
- Connect a **local Jupyter notebook** to a Livy session with `sparkmagic`, run PySpark cells on the cluster, and pull a small result back into pandas

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Why a REST gateway for Spark; session vs batch; Knox + LDAP; where the driver runs |
| Core lab | [lab_basics_livy.md](lab/lab_basics_livy.md) sections 0–5 (REST with `curl`, session, statements, batch) |
| Jupyter (laptop) | [lab_basics_livy.md](lab/lab_basics_livy.md) section 6 with the notebooks in [lab/notebooks](lab/notebooks/) |
| Optional | Section 7 (failure signals, Livy vs `spark-submit`) |
| Stretch | [lab_basics_livy.md](lab/lab_basics_livy.md) stretch |
| Self-check | `./09-basics-livy/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls  
- [trainer/demos.md](trainer/demos.md) — Livy server logs, Spark UI of a session, session timeout (trainer-only)  
- [trainer/deep-dive.md](trainer/deep-dive.md) — architecture, authentication and impersonation, Livy vs alternatives

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./09-basics-livy/setup/setup.sh
./09-basics-livy/setup/verify.sh
```

(Needs the **Livy for Spark 3** service in the cluster, exposed through the Knox topology that authenticates against LDAP, and `LIVY_URL` in `config.env`. Ranger: same Hive `{USER}` pattern as module 06 — see [ranger README](../00-setup/admin/ranger/README.md).)

## Next module

[10-advanced-hive](../10-advanced-hive/README.md)

---
*The generation of these labs was supported by AI.*
