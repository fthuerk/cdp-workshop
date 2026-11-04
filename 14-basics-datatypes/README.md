# Module 14 — Basics: Data types across Hive, Impala and Spark

The same smart-meter-style text values, cast in Hive, Impala and Spark. You compare overflow, invalid numbers, timestamps, booleans, strings and available functions side by side, so you know where a query behaves differently after it moves to another engine.

**Estimated time:** ~40 minutes (core ~35 min + stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`)
- Hue (Hive and Impala editors) and `pyspark3` on the edge node (URLs and hosts from your handout)

## Learning goals

After this module you can:

- Register one table in the shared Metastore and query it from Hive, Impala and Spark
- Predict and compare what each engine returns for failed or overflowing `CAST`s
- Explain why `DECIMAL` is safer than `DOUBLE` for summed energy values and how result types of arithmetic differ
- Compare timestamp parsing and time-zone handling across the three engines
- Check which built-in functions exist where, and choose between Spark session UDFs and Hive-style JAR UDFs
- Write a cast check that gives the same answer in every engine

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | One Metastore, three SQL dialects; why types differ; strict vs lenient casts |
| Core lab | [lab_basics_datatypes.md](lab/lab_basics_datatypes.md) sections 0–6 |
| Stretch | [lab_basics_datatypes.md](lab/lab_basics_datatypes.md) stretch (ANSI mode, Parquet timestamps, views across engines) |
| Self-check | `./14-basics-datatypes/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, expected differences, pitfalls

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./14-basics-datatypes/setup/setup.sh
./14-basics-datatypes/setup/verify.sh
```

(Ranger: same Hive policies and default external warehouse access as module 05, plus Spark access to the same database — see [ranger README](../00-setup/admin/ranger/README.md).)

## Next module

[07-lakehouse-iceberg](../07-lakehouse-iceberg/README.md) (Iceberg adds its own type rules on top of these)

---
*The generation of these labs was supported by AI.*
