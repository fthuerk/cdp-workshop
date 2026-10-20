# Trainer demos — Module 06 Spark

Optional live-only steps — not required for participants.

## 1. Spark History Server (2 min)

After a finished `spark-submit`, open the History Server URL from Cloudera Manager and show completed stages for the batch job. Contrast with the live Spark UI during interactive section 2.

## 2. Deliberate executor OOM (section 8 dramatized)

Run the 64m executor demo on the projector; scroll `yarn logs` to the memory kill line. Relate to tuning in advanced Spark.

## 3. Skew and shuffle partitions

On a larger cluster, repartition `meter_ok` to 200 partitions before join, show one huge task in the Spark UI, then `salting` or broadcast small `prices` — conceptual only for basics track.

## 4. Hue Spark notebook

If the cohort uses Hue, open **Editor → Spark** with the same `METER_CSV` path — do not duplicate the full lab in Hue; one read + one aggregate is enough.
