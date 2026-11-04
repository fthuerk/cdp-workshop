# Deep Dive: Shuffle Hash Join vs. Shuffle Sort-Merge Join

A fully worked example with concrete DataFrames, concrete values and **real Spark hash values**
(Murmur3, seed 42 – the values were computed with the same algorithm Spark uses; e.g. `hash(1) = -559580957` matches Spark).

Goal: the trainer can walk through on a whiteboard what happens physically for

```sql
SELECT o.order_id, o.amount, c.name, c.city
FROM   orders o JOIN customers c ON o.customer_id = c.customer_id
```

---

## 0. Common basics (applies to both joins)

Both joins are **shuffle joins**. Both have the same two phases:

1. **Shuffle (Exchange)**: every row is sent to a target partition determined by the join key:

   ```
   target_partition = pmod( murmur3_hash(join_key, seed=42), spark.sql.shuffle.partitions )
   ```
   `pmod` = positive modulo (Spark's `hash()` can be negative; the result must be 0..N-1).
2. **Local join** inside each partition – this is the *only* place where the two algorithms differ:
   - **Shuffle Hash Join (SHJ)**: build a hash table from the smaller side, probe it with the other side.
   - **Shuffle Sort-Merge Join (SMJ)**: sort both sides by the key, then walk through both with two pointers.

**Key insight:** because both sides use the *same* hash function and the *same* number of partitions,
equal keys always land in the *same* partition number. So each partition can be joined completely
independently – no further communication needed.

Settings used in this example (so the plan is reproducible):

```python
spark.conf.set("spark.sql.shuffle.partitions", 4)          # 4 shuffle partitions -> easy to draw
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1) # disable broadcast join
spark.conf.set("spark.sql.adaptive.enabled", "false")      # no AQE re-planning/coalescing of our 4 partitions
```

---

## 1. The input DataFrames

### 1.1 `customers` (7 rows, the "small" side)

Stored in **2 input partitions** (as they would be read from 2 files / splits).

| input partition | customer_id | name  | city     |
|-----------------|-------------|-------|----------|
| 0               | 101         | Anna  | Wien     |
| 0               | 102         | Berta | Graz     |
| 0               | 103         | Cemal | Linz     |
| 0               | 104         | Dora  | Wien     |
| 1               | 105         | Emil  | Salzburg |
| 1               | 106         | Fritz | Wien     |
| 1               | 108         | Gerda | Graz     |

### 1.2 `orders` (10 rows, the "large" side)

Stored in **2 input partitions**.

| input partition | order_id | customer_id | amount |
|-----------------|----------|-------------|--------|
| 0               | 1        | 101         | 50     |
| 0               | 2        | 102         | 20     |
| 0               | 3        | 103         | 75     |
| 0               | 4        | 101         | 30     |
| 0               | 5        | 104         | 10     |
| 1               | 6        | 105         | 60     |
| 1               | 7        | 102         | 45     |
| 1               | 8        | **107**     | 15     |
| 1               | 9        | 106         | 80     |
| 1               | 10       | 101         | 25     |

Deliberately built-in "traps" for the discussion:

- Customer **101** has 3 orders (1:N relationship).
- Customer **102** has 2 orders.
- Order **8** references customer **107**, who does not exist in `customers` -> no match (dropped in an inner join).
- Customer **108** has no orders -> no match (dropped in an inner join).

Note that the data sits in "random" input partitions: the rows for customer 101 are in `orders` partition 0 **and** partition 1.
A local join per input partition would therefore be wrong -> we need the shuffle.

---

## 2. Step 1 (both joins): Compute the hashes and the target partition

`spark.sql.shuffle.partitions = 4`, therefore `target = pmod(hash, 4)`.

| customer_id | `hash(customer_id)` (Murmur3, seed 42) | pmod(hash, 4) = target partition |
|-------------|----------------------------------------|----------------------------------|
| 101         | -818933188                             | **0**                            |
| 102         | 1684619322                             | **2**                            |
| 103         | 1527025223                             | **3**                            |
| 104         | 1692912194                             | **2**                            |
| 105         | -626095439                             | **1**                            |
| 106         | -1125161035                            | **1**                            |
| 107         | -466781912                             | **0**                            |
| 108         | 2045985810                             | **2**                            |

You can verify this live in the workshop:

```python
from pyspark.sql import functions as F
ids = spark.createDataFrame([(i,) for i in [101,102,103,104,105,106,107,108]], ["customer_id"])
ids.select("customer_id",
           F.hash("customer_id").alias("hash"),
           F.expr("pmod(hash(customer_id), 4)").alias("target_partition")).show()
```

Remarks for the trainer:

- The hash is **only** used to decide *where a row goes*. Customers 101 and 107 land together in partition 0 – a hash
  collision in the "modulo" sense – this is normal and harmless; the join condition is still checked on the real key.
- Partition sizes are not equal (0: 1+4 rows, 1: 2+2, 2: 3+3, 3: 1+1). With real data this is where **data skew** originates:
  one very frequent key (e.g. a "default" customer) = one huge partition = one slow task.
- Partition 3 receives one customer and one order, partition 0 receives one customer but 4 order rows.

---

## 3. Step 2 (both joins): The shuffle (Exchange) – what lands where

Every map task (one per input partition) writes its rows into 4 shuffle files (one per target partition).
Every reduce task (one per target partition) then fetches "its" slice from all map tasks over the network.

```
                 MAP SIDE (input partitions)                   REDUCE SIDE (shuffle partitions)

 customers  P0: 101,102,103,104  ──┐                       ┌──> Partition 0: cust {101}
 customers  P1: 105,106,108      ──┤   hash(key) % 4       ├──> Partition 1: cust {105,106}
                                   ├──────────────────────>├──> Partition 2: cust {102,104,108}
 orders     P0: 101,102,103,101,104┤                       ├──> Partition 3: cust {103}
 orders     P1: 105,102,107,106,101┘                       └
```

Result after the shuffle (the same for SHJ and SMJ). Order of rows within a partition is **not** guaranteed
(it depends on which map task finishes first); shown here in arrival order:

| shuffle partition | customers rows (key)          | orders rows (order_id, customer_id) |
|-------------------|-------------------------------|-------------------------------------|
| **0**             | 101                           | (1,101), (4,101), (10,101), (8,107) |
| **1**             | 105, 106                      | (6,105), (9,106)                    |
| **2**             | 102, 104, 108                 | (2,102), (5,104), (7,102)           |
| **3**             | 103                           | (3,103)                             |

Check: customers 1+2+3+1 = 7 ✔, orders 4+2+3+1 = 10 ✔.

From here on the two algorithms differ. Every shuffle partition is processed by **one task**, independent of the others.

---

## 4. Shuffle Hash Join (SHJ)

### 4.1 How to get it

By default Spark prefers Sort-Merge Join (`spark.sql.join.preferSortMergeJoin=true`). SHJ is chosen if

- you give a hint, or
- `spark.sql.join.preferSortMergeJoin=false` **and** one side is "much smaller" (about 3x smaller than the other) and its
  per-partition data fits into memory.

```python
orders.join(customers.hint("SHUFFLE_HASH"), "customer_id")
# or SQL: SELECT /*+ SHUFFLE_HASH(c) */ ...
```

`explain()` shows:

```
ShuffledHashJoin [customer_id#..], [customer_id#..], Inner, BuildRight
:- Exchange hashpartitioning(customer_id#.., 4)        <- orders  (stream side)
+- Exchange hashpartitioning(customer_id#.., 4)        <- customers (build side)
```

### 4.2 Algorithm (per shuffle partition)

1. **Build phase**: read the *build side* (smaller table = `customers`) completely and put it into an in-memory
   hash table: `key -> row(s)`.
2. **Probe phase**: stream the *other side* (`orders`) row by row. For each row look up its key in the hash table.
   Match -> emit joined row(s). No match -> inner join drops it.
3. No sorting at all. The streamed side is never held in memory completely.

> The hash table inside the task (Spark's `HashedRelation`) uses *its own* hashing of the key. It is **not** the same
> as the Murmur3 value used for choosing the shuffle partition. Two different hashes, two different purposes:
> hash #1 = *which task?* (shuffle), hash #2 = *which bucket in the in-memory table?* (build/probe).

### 4.3 Step-by-step per partition

**Partition 0** (task 0)

Build side (customers) -> hash table:

| key | row                  |
|-----|----------------------|
| 101 | (101, Anna, Wien)    |

Probe with orders (streamed, no sorting):

| probed order | lookup key | found?                   | output                      |
|--------------|-----------|---------------------------|-----------------------------|
| (1, 101, 50) | 101       | yes -> Anna               | (1, 50, Anna, Wien)         |
| (4, 101, 30) | 101       | yes -> Anna               | (4, 30, Anna, Wien)         |
| (10,101, 25) | 101       | yes -> Anna               | (10, 25, Anna, Wien)        |
| (8, 107, 15) | 107       | **no** (not in table)     | dropped (inner join)        |

-> 3 output rows.

**Partition 1** (task 1)

Hash table: `105 -> Emil/Salzburg`, `106 -> Fritz/Wien`

| probed order  | key | found? | output                 |
|---------------|-----|--------|------------------------|
| (6, 105, 60)  | 105 | yes    | (6, 60, Emil, Salzburg)|
| (9, 106, 80)  | 106 | yes    | (9, 80, Fritz, Wien)   |

-> 2 output rows.

**Partition 2** (task 2)

Hash table: `102 -> Berta/Graz`, `104 -> Dora/Wien`, `108 -> Gerda/Graz`

| probed order  | key | found?                   | output                |
|---------------|-----|--------------------------|-----------------------|
| (2, 102, 20)  | 102 | yes                      | (2, 20, Berta, Graz)  |
| (5, 104, 10)  | 104 | yes                      | (5, 10, Dora, Wien)   |
| (7, 102, 45)  | 102 | yes                      | (7, 45, Berta, Graz)  |

-> 3 output rows. Customer 108 (Gerda) sits in the table but is never probed -> no output.

**Partition 3** (task 3)

Hash table: `103 -> Cemal/Linz`

| probed order  | key | found? | output               |
|---------------|-----|--------|----------------------|
| (3, 103, 75)  | 103 | yes    | (3, 75, Cemal, Linz) |

-> 1 output row.

### 4.4 Characteristics of SHJ

| Aspect              | Statement                                                                                           |
|---------------------|-----------------------------------------------------------------------------------------------------|
| CPU                 | Cheap: no sort, O(n + m)                                                                            |
| Memory              | **Risky**: the *whole build side of each partition* must fit in memory (hash table). Skew on the build side -> OOM. Spark cannot spill the hash table (only falls back in some versions/configs). |
| Network/Disk        | Both sides shuffled (same as SMJ)                                                                   |
| Best when           | One side much smaller than the other, but too big to broadcast; keys evenly distributed             |
| Outer joins         | Supported (build side must be the "non-preserved" side for left/right outer)                        |

---

## 5. Shuffle Sort-Merge Join (SMJ) - the Spark default

### 5.1 How to get it

Default for equi-joins on sortable keys when broadcast is not possible.

```python
orders.join(customers.hint("MERGE"), "customer_id")
# or SQL: SELECT /*+ MERGE(c) */ ...
```

`explain()` shows:

```
SortMergeJoin [customer_id#..], [customer_id#..], Inner
:- Sort [customer_id#.. ASC NULLS FIRST], false, 0
:  +- Exchange hashpartitioning(customer_id#.., 4)
+- Sort [customer_id#.. ASC NULLS FIRST], false, 0
   +- Exchange hashpartitioning(customer_id#.., 4)
```

Note the extra `Sort` nodes **above** each `Exchange` - this is the essential difference to SHJ.

### 5.2 Algorithm (per shuffle partition)

1. Same shuffle as above (Section 3).
2. **Sort** both sides by the join key *inside the partition* (external sort, can spill to disk).
3. **Merge**: keep one pointer on each side.
   - left key < right key -> advance left
   - left key > right key -> advance right
   - equal -> collect all rows with this key on both sides, emit the cross product of the group, advance both.

### 5.3 State after the sort (same shuffle result as in section 3, now sorted)

| partition | customers sorted        | orders sorted by customer_id                 |
|-----------|-------------------------|----------------------------------------------|
| 0         | 101                     | 101(o1), 101(o4), 101(o10), 107(o8)          |
| 1         | 105, 106                | 105(o6), 106(o9)                             |
| 2         | 102, 104, 108           | 102(o2), 102(o7), 104(o5)                    |
| 3         | 103                     | 103(o3)                                      |

Note how partition 0 and partition 2 changed: in partition 2 the orders arrived as `(2,102), (5,104), (7,102)` and
are now ordered `102, 102, 104`. Sorting is what makes the cheap merge possible.

### 5.4 Step-by-step merge

Notation: **L** = customers pointer (left side), **R** = orders pointer (right side). (Which side is "left" is irrelevant for the logic.)

**Partition 0**

| step | L (customer) | R (order)  | compare      | action                                                                  |
|------|--------------|------------|--------------|-------------------------------------------------------------------------|
| 1    | 101          | 101 (o1)   | equal        | group on R = {o1, o4, o10}, group on L = {Anna} -> emit 3 rows           |
| 2    | end of L     | 107 (o8)   | L exhausted  | nothing left to match -> o8 dropped, partition done                      |

Output: (1,50,Anna,Wien), (4,30,Anna,Wien), (10,25,Anna,Wien). Note step 2: with an inner join we can **stop early** once one side is exhausted.

**Partition 1**

| step | L   | R        | compare | action                      |
|------|-----|----------|---------|-----------------------------|
| 1    | 105 | 105 (o6) | equal   | emit (6,60,Emil,Salzburg)   |
| 2    | 106 | 106 (o9) | equal   | emit (9,80,Fritz,Wien)      |
| 3    | end | end      | -       | done                        |

**Partition 2**

| step | L   | R        | compare   | action                                                         |
|------|-----|----------|-----------|----------------------------------------------------------------|
| 1    | 102 | 102 (o2) | equal     | group R = {o2, o7}, L = {Berta} -> emit (2,20,Berta,Graz), (7,45,Berta,Graz) |
| 2    | 104 | 104 (o5) | equal     | emit (5,10,Dora,Wien)                                          |
| 3    | 108 | end of R | R exhausted | Gerda has no orders -> stop                                  |

**Partition 3**

| step | L   | R        | compare | action                    |
|------|-----|----------|---------|---------------------------|
| 1    | 103 | 103 (o3) | equal   | emit (3,75,Cemal,Linz)    |

A "less/greater" case (not occurring in the inner-join data above but important to explain) - suppose L = 104, R = 107:
104 < 107 -> advance L; the next L is 108; 108 > 107 -> advance R, and so on. Each pointer only ever moves **forward**, so
the merge is a single pass: O(n + m) after the sort.

### 5.5 Characteristics of SMJ

| Aspect              | Statement                                                                                                  |
|---------------------|------------------------------------------------------------------------------------------------------------|
| CPU                 | Higher: two sorts, O(n log n + m log m)                                                                    |
| Memory              | **Robust**: sorts can spill to disk; merge needs only the current key group in memory. Scales to huge tables |
| Network/Disk        | Both sides shuffled (same as SHJ)                                                                          |
| Best when           | Both sides large; the safe default                                                                         |
| Weak spot           | Skewed key: one giant group in one partition. (AQE skew-join handling splits such partitions: `spark.sql.adaptive.skewJoin.enabled`) |

---

## 6. Both give the same result

| order_id | amount | name  | city     |
|----------|--------|-------|----------|
| 1        | 50     | Anna  | Wien     |
| 4        | 30     | Anna  | Wien     |
| 10       | 25     | Anna  | Wien     |
| 6        | 60     | Emil  | Salzburg |
| 9        | 80     | Fritz | Wien     |
| 2        | 20     | Berta | Graz     |
| 7        | 45     | Berta | Graz     |
| 5        | 10     | Dora  | Wien     |
| 3        | 75     | Cemal | Linz     |

9 rows (3+2+3+1). Dropped: order 8 (customer 107 unknown) and customer 108 (Gerda, no orders).
Row order of the final output is not guaranteed.

With `LEFT JOIN orders -> customers` order 8 would appear with `name = NULL, city = NULL`;
with a `FULL OUTER` join Gerda would additionally appear with `order_id = NULL`.

---

## 7. Side-by-side summary

| Step                    | Shuffle Hash Join                         | Shuffle Sort-Merge Join                      |
|-------------------------|-------------------------------------------|----------------------------------------------|
| 1. Exchange (hash % 4)  | yes, both sides                           | yes, both sides (identical)                  |
| 2. Local preparation    | build hash table from small side          | sort both sides by key                       |
| 3. Local matching       | probe table row by row                    | two-pointer merge                            |
| Memory need             | whole build side per partition            | small (spills to disk)                       |
| CPU                     | lower                                     | higher (sorting)                             |
| Output order            | order of the streamed side                | sorted by join key (per partition)           |
| Spark default?          | no (hint / `preferSortMergeJoin=false`)   | yes                                          |
| Typical failure         | OOM on skewed/too large build side        | slow task on skewed key                      |

Join strategy ladder in Spark (simplified): Broadcast Hash Join (if one side fits the broadcast threshold) ->
Shuffle Hash Join (if enabled/hinted and one side much smaller) -> **Sort-Merge Join** (default) -> Cartesian / Broadcast Nested Loop (non-equi joins).

---

## 8. Live demo code (PySpark)

```python
from pyspark.sql import functions as F

spark.conf.set("spark.sql.shuffle.partitions", 4)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)
spark.conf.set("spark.sql.adaptive.enabled", "false")

customers = spark.createDataFrame([
    (101, "Anna",  "Wien"), (102, "Berta", "Graz"), (103, "Cemal", "Linz"),
    (104, "Dora",  "Wien"), (105, "Emil",  "Salzburg"), (106, "Fritz", "Wien"),
    (108, "Gerda", "Graz")],
    ["customer_id", "name", "city"])

orders = spark.createDataFrame([
    (1, 101, 50), (2, 102, 20), (3, 103, 75), (4, 101, 30), (5, 104, 10),
    (6, 105, 60), (7, 102, 45), (8, 107, 15), (9, 106, 80), (10, 101, 25)],
    ["order_id", "customer_id", "amount"])

# 1) Show hashes + target partition of the keys
orders.select("order_id", "customer_id",
              F.hash("customer_id").alias("hash"),
              F.expr("pmod(hash(customer_id), 4)").alias("target_partition")).show()

# 2) Shuffle Hash Join
shj = orders.join(customers.hint("SHUFFLE_HASH"), "customer_id")
shj.explain()
shj.show()

# 3) Sort-Merge Join
smj = orders.join(customers.hint("MERGE"), "customer_id")
smj.explain()
smj.show()

# 4) See which row is in which shuffle partition (after repartition by the same key)
(orders.repartition(4, "customer_id")
       .withColumn("partition", F.spark_partition_id())
       .orderBy("partition", "customer_id").show())
```

Caveat for step 4: `repartition(4, "customer_id")` uses the same `hashpartitioning` expression
as the join's Exchange, so the `partition` column shows exactly the target partitions from section 2/3.
In the Spark UI (SQL tab -> query -> *Exchange* node) show "shuffle records written / read" and compare the
`SortMergeJoin` node (additional `Sort` nodes, "sort time", "spill size") with the `ShuffledHashJoin` node ("build side size", "hash build time").

---

## 9. Typical questions from participants

- **Why are two different hashes involved in SHJ?** Hash #1 (Murmur3 % N) decides the partition (network).
  Hash #2 (inside `HashedRelation`) decides the bucket in the in-memory table (local).
- **Why does SMJ sort if the data was already hash-partitioned?** Hash partitioning only guarantees "same key -> same
  partition", not any order within a partition. The merge needs sorted input.
- **Why is SMJ the default if sorting is expensive?** It never fails with OOM on large data (spills), SHJ can.
- **Can we avoid the shuffle?** Yes: broadcast the small side (Broadcast Hash Join), or pre-bucket both tables by the join
  key with the same bucket count (bucketed tables / Iceberg bucket partitioning) so that no Exchange (and for SMJ no
  Sort, if also sorted within buckets) is needed.
- **What if the key is NULL?** Rows with NULL keys never match in an equi-join (they are dropped early in an inner join).
