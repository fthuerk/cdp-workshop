# Kafka hands-on lab (command line, Kerberos)

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path. Everything runs in a terminal on the edge node; there is no Hue part. Kafka keeps its data on the brokers, so this lab has no folder of its own on HDFS: you only read the smart-meter sample from `${WORKSHOP_ROOT}/data/grid_measurements`. You may use exactly **one topic of your own**, and it is named like you: the topic `<your_user>`, read by the consumer group `<your_user>`. Topic and group names are separate, so the same name does not clash.

Apache Kafka is the streaming layer of the platform. Producers append messages to a **topic**, the topic is split into **partitions**, and consumers read the messages at their own pace. In the grid monitoring use case this is how continuously arriving measurements from the transformer stations would reach the platform, instead of a daily CSV file. The brokers only talk to clients that prove who they are, so every Kafka command in this lab uses your **Kerberos ticket**.

Set your Kerberos identity once. `WORKSHOP_USER` is the short name you use with `kinit`. Start in a fresh login without a ticket; this lab does not ask for the password until section 0.

```bash
export WORKSHOP_USER="${WORKSHOP_USER:-$(whoami)}"   # default: your Linux login; change if your Kerberos name differs
```

You get your ticket in section 0, after you have seen what happens without one. Now set the rest. Replace `<broker-host>` with the broker host name from your handout (the full host name, and the port of the Kerberos/TLS listener).

```bash
# Where the data is, and which brokers to talk to (from your handout)
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust if needed
export KAFKA_BOOTSTRAP="<broker-host>:9093"
export KAFKA_CONF="/tmp/kafka-client.${WORKSHOP_USER}.properties"

# Your topic and your consumer group (both are your user name), and the shared read-only topic
export KAFKA_TOPIC="${WORKSHOP_USER}"
export KAFKA_GROUP="${WORKSHOP_USER}"
export KAFKA_SHARED="grid-measurements"

# The same connection options for each family of tools (only the flag for the config file differs)
export KAFKA_ADMIN="--bootstrap-server ${KAFKA_BOOTSTRAP} --command-config ${KAFKA_CONF}"
export KAFKA_PRODUCE="--bootstrap-server ${KAFKA_BOOTSTRAP} --producer.config ${KAFKA_CONF} --producer-property enable.idempotence=false"
export KAFKA_CONSUME="--bootstrap-server ${KAFKA_BOOTSTRAP} --consumer.config ${KAFKA_CONF}"
```

`KAFKA_ADMIN` is used by `kafka-topics`, `kafka-configs` and `kafka-consumer-groups`, `KAFKA_PRODUCE` by `kafka-console-producer`, `KAFKA_CONSUME` by `kafka-console-consumer`. `KAFKA_PRODUCE` also switches off *idempotent writes*: newer producers otherwise ask the broker for a producer ID first, which protects against duplicates when a send is retried and which you do not need in this lab. Every consumer in this lab runs with `--group "${KAFKA_GROUP}"`, because your group is the only one you may use.

This lab uses `vim` once, for the client settings file. When you paste several lines into `vim`, type `:set paste` (Enter) before `i`; otherwise auto-indent garbles the text. Save and leave with Esc, then `:wq` (Enter).

---

## 0. Orient — connect with your ticket

**Goal:** Tell the Kafka tools how to use your Kerberos ticket, see what a missing ticket looks like, then get a ticket and list the topics you may see.

A Kafka client needs a small properties file. Create it once; all tools in this lab read it:

```bash
vim "${KAFKA_CONF}"
```

In `vim`: `:set paste` (Enter), `i`, paste the lines below, Esc, `:wq` (Enter).

```properties
security.protocol=SASL_SSL
sasl.mechanism=GSSAPI
sasl.kerberos.service.name=kafka
sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required useTicketCache=true;
```

What each line does:

- `security.protocol=SASL_SSL` — log in with SASL and encrypt the connection with TLS.
- `sasl.mechanism=GSSAPI` — GSSAPI is the SASL name for Kerberos.
- `sasl.kerberos.service.name=kafka` — the brokers run as `kafka/<broker-host>@<REALM>`; the client asks the KDC for a ticket for exactly this service.
- `sasl.jaas.config` — where the Kerberos login comes from. `useTicketCache=true` means: use the ticket you got with `kinit`. There is no password and no keytab in the file.

You do not have a ticket yet. Try to list the topics anyway:

> 🔴 **Failure case — an error is expected here.** Run it, read the message, then get your ticket with the next block.

```bash
# FAILURE CASE: expected to fail with a LoginException (the client is "being asked for a password")
kafka-topics ${KAFKA_ADMIN} --list
```

The Kafka tools never ask for a password: if the ticket cache has no valid ticket, the login fails right away with a `LoginException` (often wrapped in `Failed to create new KafkaAdminClient`). Remember this message: it means *you have no (valid) ticket*. (If the command worked, you still had a ticket from an earlier session: run `kdestroy` and try again.) Get your ticket:

```bash
kinit "${WORKSHOP_USER}"
```

Now list the topics you are allowed to see:

```bash
kafka-topics ${KAFKA_ADMIN} --list
```

You should see at least `grid-measurements`, the shared topic of this workshop. Kafka only lists topics that you may *describe*; the authorization is checked per topic (section 6).

**Check question:** The same command failed before `kinit` and worked after it. What did the brokers learn from your ticket, and what do the TLS part (`SASL_SSL`) and the Kerberos part (`GSSAPI`) each protect?

---

## 1. Create your topic

**Goal:** Create your topic with three partitions and read its layout.

A topic is a named, append-only log. You decide how many **partitions** it has (the unit of parallelism and ordering) and how many **replicas** each partition gets (copies on different brokers). Your topic carries your user name:

```bash
# Create your topic; --if-not-exists lets you repeat the command
kafka-topics ${KAFKA_ADMIN} --create --if-not-exists --topic "${KAFKA_TOPIC}" --partitions 3 --replication-factor 3

# Show how Kafka laid it out
kafka-topics ${KAFKA_ADMIN} --describe --topic "${KAFKA_TOPIC}"
```

You should see one summary line (`PartitionCount: 3`, `ReplicationFactor: 3`, `Configs: ...`) and three partition lines. Read a partition line like this (the order of the fields is the same everywhere):

- **Partition** — number `0`, `1` or `2`.
- **Leader** — the broker (ID) that handles all reads and writes of this partition.
- **Replicas** — all brokers that keep a copy.
- **Isr** — *in-sync replicas*: the copies that are currently up to date. It should list the same brokers as `Replicas`.

Any other topic name is refused: you may create only the topic named like you.

**Check question:** With 3 partitions and replication factor 3, how many copies of each message exist, and how many consumers of one group can read this topic in parallel?

---

## 2. Produce and consume

**Goal:** Send a first message, then the smart-meter sample, and read both with your consumer group.

### Hello world

Start small: one message, no key. The producer reads its input from the pipe, one line is one message:

```bash
echo "hello world" | kafka-console-producer ${KAFKA_PRODUCE} --topic "${KAFKA_TOPIC}"
```

No output means success. Read it back as your consumer group; the new group starts at the beginning of the topic, and `--max-messages 1` ends the consumer after one message:

```bash
kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_TOPIC}" --group "${KAFKA_GROUP}" --from-beginning --max-messages 1
```

You should see `hello world`. Your group now has a position in the topic: it has read one message.

### The smart-meter sample, live

Now the real data. First look at it. The first line is the CSV header, the second column is the transformer station:

```bash
hdfs dfs -cat "${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv" | head -3
```

A Kafka message has a **key** and a **value**. Messages with the same key always go to the same partition, so their order is kept. You will use the station as key, because the readings of one station must stay in order.

Open a **second terminal** on the edge node (a new SSH session). Both sessions use the same Kerberos ticket cache, so you do not need another `kinit`; if `klist` shows no ticket there, run `kinit "${WORKSHOP_USER}"` in its own block first. In terminal 2, set the variables the consumer needs:

```bash
# Terminal 2: variables for the consumer
export WORKSHOP_USER="<your_user>"
export KAFKA_BOOTSTRAP="<broker-host>:9093"
export KAFKA_CONF="/tmp/kafka-client.${WORKSHOP_USER}.properties"

# Terminal 2: topic, group and connection options
export KAFKA_TOPIC="${WORKSHOP_USER}"
export KAFKA_GROUP="${WORKSHOP_USER}"
export KAFKA_CONSUME="--bootstrap-server ${KAFKA_BOOTSTRAP} --consumer.config ${KAFKA_CONF}"
```

Start the consumer in terminal 2. It continues behind `hello world` (the position of your group), prints key, partition and offset of every message, and stops after 15 messages. Right now there is nothing new, so it waits:

```bash
# Terminal 2: wait for the 15 readings of the sample
kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_TOPIC}" --group "${KAFKA_GROUP}" --max-messages 15 \
  --property print.key=true --property print.partition=true --property print.offset=true
```

Now send the data from terminal 1. The pipeline cuts off the header (`tail`), puts the station in front of each line as key (`awk`), and hands the lines to the producer, which splits key and value at the `|`:

```bash
# Terminal 1: read the sample from HDFS and produce it, keyed by station
hdfs dfs -cat "${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv" \
  | tail -n +2 \
  | awk -F, '{print $2 "|" $0}' \
  | kafka-console-producer ${KAFKA_PRODUCE} --topic "${KAFKA_TOPIC}" --property parse.key=true --property "key.separator=|"
```

In terminal 2 the 15 messages appear as soon as the producer sends them, then the consumer ends. The fields of each output line are tab-separated: time stamp, partition, offset, key, value (the exact format depends on the Kafka version). You can close terminal 2 now.

**Check question:** Look at the partition column. Which stations share a partition, and does a station ever appear in two partitions? Why is that useful for the readings of one station?

---

## 3. Consumer group position and lag

**Goal:** Read the position of your consumer group, create lag with new data, and let the group catch up.

A **consumer group** is a set of consumers that share the work: each partition is read by one member of the group. The position of the group in every partition is stored in Kafka. Ask for it in terminal 1:

```bash
kafka-consumer-groups ${KAFKA_ADMIN} --describe --group "${KAFKA_GROUP}"
```

Columns of the group output:

- **GROUP, TOPIC, PARTITION** — what the row is about; one row per partition.
- **CURRENT-OFFSET** — the next message your group will read in this partition.
- **LOG-END-OFFSET** — the offset after the newest message in the partition.
- **LAG** — `LOG-END-OFFSET` minus `CURRENT-OFFSET`: how many messages the group has not read yet.
- **CONSUMER-ID, HOST, CLIENT-ID** — the member that holds the partition. They show `-` because your consumer already ended and the group is empty.

You should see `LAG` 0 in every row: the group has read everything. Now new readings arrive while your group is not running. Send the last five rows of the sample again, then look at the group:

```bash
# Produce five more messages (the group is not running)
hdfs dfs -cat "${WORKSHOP_ROOT}/data/grid_measurements/sample-grid-measurements.csv" \
  | tail -n 5 \
  | awk -F, '{print $2 "|" $0}' \
  | kafka-console-producer ${KAFKA_PRODUCE} --topic "${KAFKA_TOPIC}" --property parse.key=true --property "key.separator=|"

# The lag now adds up to 5
kafka-consumer-groups ${KAFKA_ADMIN} --describe --group "${KAFKA_GROUP}"
```

Let the group catch up. It continues where it stopped; `--from-beginning` is not needed because the group already has a position:

```bash
# Read only the five new messages
kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_TOPIC}" --group "${KAFKA_GROUP}" --max-messages 5

# The lag is 0 again
kafka-consumer-groups ${KAFKA_ADMIN} --describe --group "${KAFKA_GROUP}"
```

**Check question:** A dashboard is fed by a consumer group and its lag grows steadily. What does that tell you, and is any data lost?

---

## 4. Messages stay: reset the group and read again

**Goal:** Move your group back to the start and read the same messages a second time.

Your group has read all 21 messages, but they are still in the topic. Kafka is not a queue that hands a message out once: the topic is a log, and each group keeps its own **position** (the offset) in it. Messages are removed only when the retention time of the topic is over (section 5). To read again you only have to move the position of the group. Preview the reset first, then run it (the group must have no running consumer):

```bash
# Preview: what would the offsets be?
kafka-consumer-groups ${KAFKA_ADMIN} --group "${KAFKA_GROUP}" --topic "${KAFKA_TOPIC}" --reset-offsets --to-earliest --dry-run

# Do it, then look at the lag
kafka-consumer-groups ${KAFKA_ADMIN} --group "${KAFKA_GROUP}" --topic "${KAFKA_TOPIC}" --reset-offsets --to-earliest --execute
kafka-consumer-groups ${KAFKA_ADMIN} --describe --group "${KAFKA_GROUP}"
```

`CURRENT-OFFSET` is 0 in every partition, and `LAG` equals the number of messages in the partition (21 in total). The data did not change; only the position of your group did. Now read all 21 messages again:

```bash
kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_TOPIC}" --group "${KAFKA_GROUP}" --max-messages 21 \
  --property print.key=true --property print.partition=true --property print.offset=true
```

You get `hello world` first, then the same partitions and offsets as in section 2, plus the five new messages. Re-processing data after a bug fix works exactly like this.

**Check question:** What is the difference to a file you read from HDFS, and what is the difference to a message queue?

---

## 5. Topic configuration and retention

**Goal:** Change how long Kafka keeps messages of your topic.

Per-topic settings override the broker defaults. Set the retention to one hour and read it back:

```bash
# Keep messages for one hour (3,600,000 ms)
kafka-configs ${KAFKA_ADMIN} --alter --entity-type topics --entity-name "${KAFKA_TOPIC}" --add-config retention.ms=3600000

# Read the overrides of the topic
kafka-configs ${KAFKA_ADMIN} --describe --entity-type topics --entity-name "${KAFKA_TOPIC}"
```

You should see `retention.ms=3600000` in the list of dynamic (topic-level) configs. After that time Kafka deletes old log segments, whether they were read or not.

**Check question:** Is Kafka a place to keep the measurements for years? Which platform component would hold them long term?

---

## 6. Authentication is not authorization

**Goal:** Read from the shared topic, fail to write to it, and tell which part of the platform said no.

Your instructor filled the topic `grid-measurements` with the same sample. You may read it (your group has no position in this topic yet, so it starts at the beginning):

```bash
kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_SHARED}" --group "${KAFKA_GROUP}" --from-beginning --max-messages 3 \
  --property print.key=true --property print.partition=true
```

You should get three messages. Now try to write into it:

> 🔴 **Failure case — an error is expected here.** Run it, read the message, continue.

```bash
# FAILURE CASE: expected to fail with "TopicAuthorizationException: Not authorized to access topics: [grid-measurements]"
echo "TS-999|test" | kafka-console-producer ${KAFKA_PRODUCE} --topic "${KAFKA_SHARED}" --property parse.key=true --property "key.separator=|"
```

Your ticket is valid, the brokers know who you are, and still the write is refused. **Kerberos only answers "who are you?"**. Whether you may publish or consume a topic is decided by **Apache Ranger**, which the brokers ask for every request. In your own topic you have all permissions, in the shared topic only consume.

*Optional:* in the Ranger UI (link on the Knox home page) open **Audit → Access** and filter by your user name and the Kafka service. You find the denied `publish` request of the command above.

**Check question:** Which tool stops you here, and which tool would you use to see why?

---

## Stretch (optional)

1. **Read one partition.** Pick a partition from section 4 and read only it. The consumer waits for more messages, so stop it with `--timeout-ms` (a timeout message at the end is normal):

   ```bash
   kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_TOPIC}" --group "${KAFKA_GROUP}" --partition 0 --offset earliest --timeout-ms 10000 \
     --property print.key=true
   ```

2. **Add partitions.** Partitions can only be added, never removed. Add three, send one more reading of `TS-101` and read it back with its partition. Does `TS-101` still land in the partition you saw in section 2? (The key is hashed over the *number* of partitions, so the answer can change.)

   ```bash
   # Grow your topic from 3 to 6 partitions
   kafka-topics ${KAFKA_ADMIN} --alter --topic "${KAFKA_TOPIC}" --partitions 6

   # One more reading for TS-101, then read it with your group
   echo "TS-101|2026-01-15T12:00:00Z,TS-101,GM-TS-101-A,L1,190.0" | kafka-console-producer ${KAFKA_PRODUCE} --topic "${KAFKA_TOPIC}" --property parse.key=true --property "key.separator=|"
   kafka-console-consumer ${KAFKA_CONSUME} --topic "${KAFKA_TOPIC}" --group "${KAFKA_GROUP}" --from-beginning --max-messages 1 --timeout-ms 10000 --property print.key=true --property print.partition=true
   ```

3. **Throughput.** Measure how fast a producer can write 100,000 messages of 200 bytes into your topic (you have only this one). Look at the records per second and the latency in the last line. Your group will have a lag of 100,000 afterwards, which is fine:

   ```bash
   kafka-producer-perf-test --topic "${KAFKA_TOPIC}" --num-records 100000 --record-size 200 --throughput -1 \
     --producer-props bootstrap.servers="${KAFKA_BOOTSTRAP}" enable.idempotence=false --producer.config "${KAFKA_CONF}"
   ```

4. **Optional UI.** If your instructor installed Streams Messaging Manager, open it from the Knox home page and find your topic, its partitions and the lag of your consumer group.

---

## Self-check

Run this **before** the clean-up, because it looks at your topic and your consumer group. It needs `KAFKA_BOOTSTRAP` from the setup block at the top:

```bash
./15-basics-kafka/lab/check.sh
```

If a check fails, see [troubleshooting.md](troubleshooting.md).

---

## Clean up

Remove your group, your topic and the client file:

```bash
# Group and topic
kafka-consumer-groups ${KAFKA_ADMIN} --delete --group "${KAFKA_GROUP}"
kafka-topics ${KAFKA_ADMIN} --delete --if-exists --topic "${KAFKA_TOPIC}"

# Client settings file (you can recreate it from section 0)
rm -f "${KAFKA_CONF}"
```

The shared topic `grid-measurements` stays; you cannot delete it.

---
*The generation of these labs was supported by AI.*
