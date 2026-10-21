# Module 10 — Advanced: Hive

Complex Hive SQL on the grid monitoring pilot data: joins beyond the inner join, window functions such as `RANK` and `LAG`, arrays, maps, and structs, subtotals with `ROLLUP`, and geo data as WKT.

**Estimated time:** ~75 minutes (core ~60 min + stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket (`WORKSHOP_USER` + `kinit`) and the HiveServer2 JDBC URL from your handout

## Learning goals

After this module you can:

- Use left joins as anti-joins, semi-joins, derived-key joins, and self joins, and detect a join that multiplies rows
- Rank rows with `ROW_NUMBER`, `RANK`, and `DENSE_RANK`, and select the top row per group
- Compare neighbouring rows with `LAG`/`LEAD` and compute running totals and moving averages with window frames
- Build and unpack arrays, maps, and structs with `collect_list`, `named_struct`, and `LATERAL VIEW explode`
- Produce subtotals with `ROLLUP`, `CUBE`, and `GROUPING SETS`
- Build and parse geometries in WKT, and compute a distance between stations in SQL

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | How a window differs from `GROUP BY`; why complex types exist in a columnar world |
| Core lab | [lab_advanced_hive.md](lab/lab_advanced_hive.md) sections 0–4 |
| Stretch | [lab_advanced_hive.md](lab/lab_advanced_hive.md) stretch tasks |
| Self-check | `./10-advanced-hive/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./10-advanced-hive/setup/setup.sh
./10-advanced-hive/setup/verify.sh
```

The lab is self-contained and safe to repeat: section 0 creates its own database, tables, and view from the shared sample data (`IF NOT EXISTS`, `cp -f`). Nothing from the basics lab is needed. Ranger policies for Hive are the same as for module 04 — see the [ranger README](../00-setup/admin/ranger/README.md).

## Next module

[11-advanced-spark](../11-advanced-spark/README.md) (planned)
