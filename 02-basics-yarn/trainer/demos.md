# Trainer live demos — YARN

Optional extras while participants run the lab. Use `${WORKSHOP_ROOT}` from your cluster handout.

---

## 1. ResourceManager UI — application timeline

**Goal:** Show containers, node assignment, and diagnostics for a finished MapReduce app.

Open RM UI (Knox or direct host). Walk through one participant’s word-count application: attempt, containers, logs link.

**Talking point:** Same view supports Hive/Spark troubleshooting tomorrow.

---

## 2. Rejected application (queue full)

**Goal:** Show `ACCEPTED` vs `SUBMITTED` vs failure when capacity is zero.

Only if you have a safe **test queue** with zero capacity; do not disrupt production queues.

**Talking point:** Capacity scheduler protects multi-tenant grid analytics.

---

## 3. Kill a long-running job

**Goal:** Demonstrate `yarn application -kill`.

Start a deliberately slow job (large pi iteration) in the background, then kill:

```bash
hadoop jar "${MAPRED_EXAMPLES_JAR}" pi 16 100000000 &
# note application_ id from yarn application -list
yarn application -kill <application_id>
```

Participants are **not** required to kill jobs in the lab.

---

## 4. Link back to HDFS lab data

**Goal:** Reinforce one copy of pilot CSVs on HDFS consumed by many engines.

Show `${WORKSHOP_ROOT}/data/landisgyr/…` in File Browser and the same path under `/user/<participant>/` in a running Spark app env (Spark UI → Environment).
