# Trainer demos — Module 05 Impala

Optional live-only steps — not required for participants.

## 1. Impala query profile (30 s)

In `impala-shell`, run section 2’s aggregation with a profile:

```sql
SELECT station_id, COUNT(*) FROM impala_meter GROUP BY station_id;
```

Then show the runtime profile summary (version-specific command — often `PROFILE` or the shell’s summary on exit). Contrast with Hive’s Tez DAG in the ResourceManager UI for the same SQL.

## 2. Stale metadata without INVALIDATE

While participants work on section 2, append a file to one trainer table path on HDFS and re-run `COUNT(*)` until the room agrees counts can lie until metadata refresh — then run `INVALIDATE METADATA`.

## 3. Hue dual editor

Split screen: **Impala** editor vs **Hive** editor, same query text. Good for cohorts that skip CLI in other modules.
