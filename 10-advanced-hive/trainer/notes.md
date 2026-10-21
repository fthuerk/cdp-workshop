# Trainer notes — Module 10 Advanced Hive

**Dry-run status:** the lab SQL has not been run on the target cluster yet. Do one full run with a normal participant account before the session. Check in particular `GROUPING__ID` (its values differ between Hive versions), the optional `ST_` functions, and the regular expressions in section 4 (backslashes must be doubled in Hive string literals).

## Suggested timing (~75 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Section 0: tables and view (participants who did the basics lab only repeat the copy) |
| 10–25 | Section 1: complex joins — spend time on the row-multiplying join |
| 25–45 | Section 2: window functions — draw one partition on the whiteboard first |
| 45–60 | Section 3: complex types, `ROLLUP` |
| 60–75 | Section 4: WKT; `check.sh` |

If you run short, drop the semi-join, `NTILE`/`PERCENT_RANK`, and the optional `ST_` step.

## Check-question answers

1. **Doubled rows (1):** Each timestamp exists twice in the weather table (two weather stations), so the key is not unique on one side. Check uniqueness with `GROUP BY key HAVING COUNT(*) > 1` and compare row counts before and after the join. The cost is an estimate because a 15-minute reading is priced with the price of its whole hour and the power value is treated as constant for 15 minutes.  
2. **`GROUP BY` vs `OVER` (2):** `GROUP BY` collapses each group to one row; the window function keeps every row and adds the group value. To flag readings above 90 % of their station's peak use `transformer_load_pct > 0.9 * MAX(transformer_load_pct) OVER (PARTITION BY station_id)` in a subquery (a window function cannot be used in `WHERE`).  
3. **Arrays (3):** Arrays suit values that always belong together and are read together (a list of tags or event codes per reading). You lose simple filtering and joining on single values, per-value statistics, and easy reuse by tools that expect flat tables. One row per value stays the default.  
4. **WKT (4):** The WKT standard (and GIS convention x/y) writes longitude first. Swapped coordinates put Vienna near the Indian Ocean or give invalid values; no error appears in Hive because it is just text. With 100,000 stations the self join creates 10 billion pairs. Limit the pairs first with a coarse filter (grid cell, bounding box) or use a spatial engine/index.

## Pitfalls

| Symptom | Note |
|---------|------|
| `Non-equi join` error | Old or restricted settings; the lab uses small tables. Fall back to a `CROSS JOIN` with a `WHERE` condition |
| `LATERAL VIEW explode` drops stations | Expected — shows the difference to `LATERAL VIEW OUTER` |
| `SHOW FUNCTIONS LIKE 'ST_*'` empty | The ESRI spatial framework is not registered on the cluster. The step is optional |
