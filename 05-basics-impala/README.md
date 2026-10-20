# Module 05 — Basics: Impala

Interactive SQL on smart-meter sample data: same Hive Metastore as Hive, but Impala serves low-latency reads while Hive runs heavier Tez jobs. You will hit **expected errors** on row-level `UPDATE`/`DELETE` for external tables and compare query speed side by side with Hive.

**Estimated time:** ~45 minutes (core ~40 min + stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`)
- Impala coordinator options and HiveServer2 JDBC URL from your handout (`IMPALA_OPTS`, `HS2_URL`)

## Learning goals

After this module you can:

- Connect with `impala-shell` and create or use a personal database in the shared Metastore
- Register an **external** table on HDFS CSV data and run interactive aggregations
- Compare the same scan in **Impala vs Hive** (time and YARN / Tez behavior)
- Explain why **UPDATE** and **DELETE** fail on external Hive tables in both engines
- Use **`INVALIDATE METADATA`** when files change under an existing table

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Impala daemons vs HiveServer2 + Tez; shared Metastore; when to use which engine |
| Core lab | [lab_basics_impala.md](lab/lab_basics_impala.md) sections 0–5 |
| Stretch | [lab_basics_impala.md](lab/lab_basics_impala.md) stretch (Hue, EXPLAIN, transactional Hive table) |
| Self-check | `./05-basics-impala/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls  
- [trainer/demos.md](trainer/demos.md) — optional live-only comparisons

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./05-basics-impala/setup/setup.sh
./05-basics-impala/setup/verify.sh
```

(Ranger: extend Hive policies to `${WORKSHOP_ROOT}/05-impala/work` — see [ranger README](../00-setup/admin/ranger/README.md).)

## Next module

[06-basics-spark](../06-basics-spark/README.md)
