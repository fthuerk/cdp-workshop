# Trainer notes — Module 10 Advanced Hive

**Dry-run status:** the lab SQL has not been run on the target cluster yet. Do one full run with a normal participant account before the session. Check in particular `GROUPING__ID` (its values differ between Hive versions), the optional `ST_` functions, and the regular expressions in section 4 (backslashes must be doubled in Hive string literals).

**Section 5 (ACID) is also not dry-run yet.** Verify on the cluster: (1) the `CTAS` into the transactional table creates a `delta_0000001_0000001_…` directory, not a `base_` (lab 04 and its demo mention a `base_` after a CTAS — check which is true and fix the wording); (2) `ROW__ID` and `ROW__ID.writeid` work in `SELECT` and `GROUP BY`; (3) `COMPACT … AND WAIT` returns, i.e. the compactor threads are enabled; (4) participants can or cannot read `/warehouse/tablespace/managed/hive/<user>.db`. If they cannot, the demo of the folders is yours — see `04-basics-hive/trainer/demos.md`.

## Suggested timing (~90 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Section 0: tables and view (participants who did the basics lab only repeat the copy) |
| 10–25 | Section 1: complex joins — spend time on the row-multiplying join |
| 25–45 | Section 2: window functions — draw one partition on the whiteboard first |
| 45–60 | Section 3: complex types, `ROLLUP` |
| 60–70 | Section 4: WKT |
| 70–88 | Section 5: ACID, delta files, compaction (draw the directory table on the whiteboard) |
| 88–90 | `check.sh` |

If you run short, drop the semi-join, `NTILE`/`PERCENT_RANK`, the optional `ST_` step, and the nearest-neighbour query in section 4.

## Check-question answers

1. **Doubled rows (1):** Each timestamp exists twice in the weather table (two weather stations), so the key is not unique on one side. Check uniqueness with `GROUP BY key HAVING COUNT(*) > 1` and compare row counts before and after the join. The cost is an estimate because a 15-minute reading is priced with the price of its whole hour and the power value is treated as constant for 15 minutes.  
2. **`GROUP BY` vs `OVER` (2):** `GROUP BY` collapses each group to one row; the window function keeps every row and adds the group value. To flag readings above 90 % of their station's peak use `transformer_load_pct > 0.9 * MAX(transformer_load_pct) OVER (PARTITION BY station_id)` in a subquery (a window function cannot be used in `WHERE`).  
3. **Arrays (3):** Arrays suit values that always belong together and are read together (a list of tags or event codes per reading). You lose simple filtering and joining on single values, per-value statistics, and easy reuse by tools that expect flat tables. One row per value stays the default.  
4. **WKT (4):** The WKT standard (and GIS convention x/y) writes longitude first. Swapped coordinates put Vienna near the Indian Ocean or give invalid values; no error appears in Hive because it is just text. With 100,000 stations the self join creates 10 billion pairs. Limit the pairs first with a coarse filter (grid cell, bounding box) or use a spatial engine/index.
5. **ACID (5):** A file in HDFS cannot be changed, and a row has no fixed position, so a `DELETE` writes the `ROW__ID` (write ID, bucket, row ID) of each row into a new `delete_delta_` directory; readers skip those rows. An `UPDATE` is a delete plus an insert (split update). Without compaction every query must open and merge more and more small files, so read time grows with the number of statements, and the NameNode holds all the small files. A minor compaction merges deltas but keeps the deleted rows physically; only a major compaction rewrites a new `base_` without them, so the size only shrinks after a major compaction.

## Pitfalls

| Symptom | Note |
|---------|------|
| `Non-equi join` error | Old or restricted settings; the lab uses small tables. Fall back to a `CROSS JOIN` with a `WHERE` condition |
| `LATERAL VIEW explode` drops stations | Expected — shows the difference to `LATERAL VIEW OUTER` |
| `COMPACT … AND WAIT` hangs, `SHOW COMPACTIONS` stays `initiated` | Compactor threads are off on the Metastore (`hive.compactor.initiator.on`, `hive.compactor.worker.threads`) |
| `hdfs dfs -ls` on the managed folder: `Permission denied` | Expected under strict policies. Participants use `ROW__ID` and `INPUT__FILE__NAME` in SQL; `delete_delta_` directories never show up there, so show them in a trainer demo |
| Old `delta_` directories still listed after compaction | The Cleaner removes them a little later |
| `SHOW FUNCTIONS LIKE 'ST_*'` empty | The ESRI spatial framework is not registered on the cluster. The step is optional |
