# Trainer notes — Module 14 Data types across engines

**Dry-run status:** run once with a participant account before the session. The "expected" results below come from Hive 3, Impala 4 and Spark 3 behaviour as documented and as seen in practice; **verify every line on your cluster version** and correct this file. Version differences are common here.

## Suggested timing (~40 min)

| Minutes | Activity |
|---------|----------|
| 0–5 | Concept: one Metastore, three engines, three type systems; strict vs lenient casts |
| 5–12 | Sections 0–1: three sessions, table of raw text, six rows in each engine |
| 12–20 | Section 2: numeric casts, decimal vs double, result types |
| 20–27 | Section 3: timestamps and time zones |
| 27–31 | Section 4: booleans, strings, `NULL` |
| 31–37 | Section 5: function matrix, Spark UDF |
| 37–40 | Section 6: defensive cast, `check.sh` |

Tell the room early: **predict first, then run.** Differences and errors are the learning goal. If time is short, do sections 2, 3 and 5 live and give 4 and 6 as homework.

## What to expect (verify on your cluster)

| Topic | Expected observation |
|-------|----------------------|
| `CAST('abc' AS INT)` | `NULL` in Hive and Impala; `NULL` in Spark unless ANSI mode is on (then an error) |
| `2147483648` as `INT` | `NULL` (out of range) in all three by default |
| `300` as `TINYINT` | Often wraps (44) or `NULL` depending on engine/version — good discussion point |
| `0.1 + 0.2` as `DOUBLE` | `0.30000000000000004` everywhere; `DECIMAL` gives `0.30` |
| `DECIMAL / DECIMAL` | Result precision and scale differ by engine (Hive and Spark use similar rules, Impala differs) |
| `7 / 2` | `3.5` (`DOUBLE`) in all three; integer division is `DIV` |
| Timestamp formats | `2026-01-15 08:00:00` parses everywhere; `T…Z` and `15.01.2026 08:00` differ; `2026-02-30` is `NULL` in most, check Spark |
| `unix_timestamp` | Impala treats timestamps as UTC by default; Hive and Spark use the session/local time zone — expect a 1-hour (winter) difference in row 1 |
| DST gap (row 6) | Engines differ: shifted, `NULL` or unchanged |
| `CAST('false' AS BOOLEAN)` | Hive historically treats any non-empty text as true in some versions — check; Spark accepts `yes`/`1`/`y`; Impala is stricter |
| `LENGTH('Straße')` | Hive and Spark count characters (6); Impala `LENGTH` may count bytes (7), `UTF8_LENGTH` gives 6 |
| Empty field vs `NULL` text | Both are non-null `STRING`s in a text table (the SerDe null format is `\N`) |
| `split`, `date_format` | Hive and Spark yes; Impala no (`split_part`, `from_timestamp` instead) — check `split_part` in Hive and Spark by version |

## Check-question answers

1. **Metastore (1):** The table definition lives in the Metastore, which all three engines use. Impala caches metadata, so tables created elsewhere need `INVALIDATE METADATA`; later file changes need `REFRESH`.
2. **Decimal sums moving to Spark (2):** (a) result precision and scale of arithmetic, (b) overflow and rounding behaviour (`NULL` vs error vs different scale); also ANSI mode and implicit casts between `DECIMAL` and `DOUBLE`.
3. **UTC timestamps (3):** Use whichever engine parses the `T…Z` text directly (usually Spark), and in the others replace `T`/`Z` first (`regexp_replace`) or convert with `to_timestamp` / `from_timestamp` and an explicit format. Store timestamps as UTC and convert only on display.
4. **Boolean validation (4):** Casts differ in what they accept and in how they treat unknown text (`NULL` vs `true` vs error), so `IS NOT NULL` proves nothing portable. Compare against the allowed text values instead: `raw_flag IN ('true', 'false')`.
5. **One implementation for three engines (5):** A Java UDF built on the Hive API in a JAR on HDFS, registered in each engine. You give up the quick Python iteration and need a build step and a deployment path; Spark-only Python UDFs are easier but invisible to Hive and Impala.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| Impala sees no table | `INVALIDATE METADATA` after the table was created in Hive |
| Participants fix the errors | Say it again: errors and `NULL`s are the result, write them down |
| Spark ANSI mode differs by cluster | Show `spark.sql.ansi.enabled` in section 0; use the stretch to flip it |
| Results differ from this file | Update the table above; this module is a version-specific comparison |
| Time zone confusion | Check the edge node and Spark session time zones first; Vienna is UTC+1 (winter), UTC+2 (summer) |

## Admin

[setup/setup.sh](../setup/setup.sh) writes the six-row `edge-values.csv` under `${WORKSHOP_ROOT}/14-datatypes/edge/`. No tables are created centrally.

## After module

[Iceberg (07)](../../07-lakehouse-iceberg/README.md) adds its own type rules (`timestamp` vs `timestamptz`, partition transforms). Advanced Hive ([10](../../10-advanced-hive/README.md)) covers complex types.
