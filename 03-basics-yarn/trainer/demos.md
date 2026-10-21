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

## 3. Kill the ApplicationMaster — second attempt

**Goal:** Show that the AM is just a container: if it dies, YARN starts a new attempt and the job continues. Follows [lab section 5](../lab/lab_basics_yarn.md), where participants only observe the AM.

In terminal 1 start a slow job; in terminal 2 find the AM container of attempt 1 (`yarn applicationattempt -list`, `yarn container -list`) and force it down:

```bash
yarn jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar pi 16 100000000
yarn container -signal "<am-container-id>" FORCEFUL_SHUTDOWN
yarn applicationattempt -list "<application-id>"
```

A second attempt appears with a new AM container (`…_000002` in the attempt number, new container ID). Requires Hadoop 3.1+ and permission to signal your own container; otherwise show attempts in the RM UI only.

**Talking point:** Task containers dying is handled by the AM; AM dying is handled by the RM, up to the configured maximum attempts.

---

## 4. Link back to HDFS lab data

**Goal:** Reinforce one copy of the data on HDFS consumed by many engines.

Show `${WORKSHOP_ROOT}/03-yarn/input/` in File Browser, then the same path as the input argument in a running Spark app (Spark UI → Environment) and as the input of the MapReduce app in the RM UI.
