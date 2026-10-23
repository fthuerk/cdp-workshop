# Trainer notes — Module 06 Spark

**Dry-run status:** run once with a participant account before the session; `spark-submit` binary names and Spark UI links vary by CDP version.

## Suggested timing (~90 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: driver/executors, lazy eval, landing → curated; YARN + HDFS recap |
| 10–25 | Sections 0–1: PySpark on YARN, read CSV, schema by position |
| 25–35 | Section 2: cleanse, lazy vs action, 12 OK / 3 rejected |
| 35–45 | Section 3: hourly aggregates, temp view + SQL |
| 45–55 | Section 4: time join → 24 rows; inner vs left; awattar hour |
| 55–65 | Section 5: Parquet write, `hdfs dfs -ls` partitions |
| 65–75 | Section 6: `spark-submit` cluster mode, HDFS vs local script path |
| 75–85 | Section 7: `saveAsTable` into the default external location; optional Beeline |
| 85–90 | Section 8 optional or stretch; `check.sh` |

If time is tight, skip section 8 and stretch; run section 7 as a trainer demo with one shared screen.

## Check-question answers

1. **Driver location (0):** In **client** mode the driver stays on the edge node; in **cluster** mode (section 6) the driver runs in a YARN container. This lab’s interactive `pyspark --master yarn` is typically client mode unless the cluster defaults otherwise — clarify from your CM Spark config.  
2. **Explicit schema (1):** Prevents silent type widening, supports stable pipelines, and avoids a full second pass for inference on large data.  
3. **Lazy transforms (2):** No — executors start when an action runs.  
4. **Two rows per meter timestamp (4):** Inner join on time only; two weather stations share each 15-minute bucket.  
5. **Curated vs landing (5):** Landing CSVs remain under `${WORKSHOP_ROOT}/data`; curated Parquet is optimized for downstream SQL and repeatable batch jobs.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| `spark-submit` vs `spark3-submit` | Put the exact command on the handout; test from edge node |
| PySpark client cannot reach RM | Firewall or wrong `YARN_CONF_DIR` — use same edge node as other labs |
| No rows after join | Participant joined on wrong column names — weather first field must be timestamp typed as `ts_utc` |
| Section 7 `saveAsTable` fails | Enable Hive support (`spark.sql.catalogImplementation=hive`) if your cluster requires it. Do not switch to a custom `LOCATION` (needs Ranger URL policies); check the table location with `DESCRIBE FORMATTED` — it must be under the default external warehouse. Verify once on your cluster that Spark creates it as an external table |
| Small cluster, slow local check | `check.sh` uses `local[2]` — acceptable on edge node; warn if laptops not used |
| Ranger | Module 04 Hive policies on `{USER}` plus HDFS home write; optional path `${WORKSHOP_ROOT}/06-spark/work` if you redirect tables there |

## Admin

[setup/setup.sh](../setup/setup.sh) uploads `spark_cleanse_join.py` to `${WORKSHOP_ROOT}/06-spark/assets/` and creates `work/` with mode `1777` for optional shared experiments.

## After module

Module 05 Impala queries the same Metastore pattern on external CSV tables; module 11 (advanced Spark) builds multi-step pipelines on curated layers.
