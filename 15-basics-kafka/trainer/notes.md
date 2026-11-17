# Trainer notes — Module 15 Kafka

**Dry-run status:** not yet run on a cluster. Before the session, run the lab once with a participant account. Check in particular the Ranger Kafka policies (`{USER}` macro), and the exact output format of `kafka-console-consumer` (`print.partition` needs Kafka 2.7 or newer).

## Suggested timing (~55 min)

| Minutes | Activity |
|---------|----------|
| 0–10 | Concept: log, topic, partition, offset, key; brokers, leader and replicas; consumer group. Kafka in the pilot: continuous sensor feed instead of the daily CSV (optional extension) |
| 10–18 | Section 0: client file, Kerberos settings line by line, failure case before `kinit` (everybody starts without a ticket; anybody with an old ticket must `kdestroy`), then `kinit` |
| 18–24 | Section 1: create and describe the topic; read leader / replicas / ISR |
| 24–34 | Section 2: hello world first (proves login, topic and permissions), then second terminal, consumer first, then the producer. Make the room look at the partition column |
| 34–42 | Section 3: group position and lag. Let the room predict the lag before each `--describe` |
| 42–48 | Section 4: reset the group, read the 21 messages again, "consuming does not delete" |
| 48–52 | Section 5 and 6: retention; denied write to the shared topic (expected failure) |
| 52–55 | `check.sh` and clean-up |

If time is tight, skip section 5 (retention) and demo the Ranger audit from section 6 on the projector.

## Check-question answers

1. **Two protections (0):** Kerberos proves who you are (the client to the broker, and the broker to the client through mutual authentication with `kafka/<host>`); TLS encrypts the traffic and the client checks the broker certificate. The failed command before `kinit` shows the point: the brokers learn who you are only from the ticket.
2. **Copies and parallelism (1):** three copies of each message (one per replica, on three brokers); up to three consumers of one group read in parallel (one per partition), a fourth would be idle.
3. **Key and partition (2):** each station (key) always appears in exactly one partition; stations can share a partition (3 keys, 3 partitions, hash collisions are normal). Same partition means the order of one station's readings is kept; there is no order across partitions.
4. **HDFS file and queue (4):** an HDFS file is read by a path and stays; a queue hands a message out once and removes it. Kafka keeps the log for the retention time and every consumer group has its own offset, so several applications can read the same data independently and again.
5. **Growing lag (3):** the consumers are slower than the producers (or stopped). No data is lost as long as the lag stays below what retention keeps; the dashboard shows older data. If the lag exceeds the retention, messages are deleted before they are read.
6. **Long-term storage (5):** no; Kafka is a buffer with a retention time, not an archive. The long-term home in this platform is HDFS (or Iceberg/Hive tables); a Spark Streaming or NiFi flow lands the topic data there.
7. **Who says no (6):** Ranger denies the `publish`; the brokers ask Ranger for every request. The Ranger **Audit → Access** page shows the denied request with user, resource and policy.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| `Server not found in Kerberos database` | `KAFKA_BOOTSTRAP` must be the broker FQDN(s) as registered in the KDC, not an IP or an alias |
| Failure case does not fail | A participant still has a ticket from an earlier session: `kdestroy`, then repeat |
| Java cannot read the ticket | Needs a file-based credential cache (same as HDFS); a `KEYRING:` cache works for `kinit` and `klist` but not for Java |
| Producer fails with `Unexpected error in InitProducerIdResponse` | Idempotent producer (default since Kafka clients 3.0) cannot get a producer ID. Broker log: `UnsupportedOperationException` in `RangerKafkaCheckAccess.authorizeByResourceType` (Ranger Kafka plugin bug, seen with the 3.9.2.7.3.2 broker). The lab sets `enable.idempotence=false` for all producers, so `INIT_PRODUCER_ID` is never sent. Open a support case for a plugin patch; granting `Idempotent Write` on the cluster resource may avoid the crash (not verified) |
| Wrong port | `SASL_SSL` port (often 9093) vs `SASL_PLAINTEXT` (often 9092): print the value in the handout |
| `GroupAuthorizationException` | A consumer without `--group` invents `console-consumer-<n>`, which Ranger refuses (group policy is `{USER}` only). Every consumer command in the lab has `--group`; check the exported `KAFKA_GROUP` |
| Topic creation refused for the user | The topic must be named exactly like the user; `WORKSHOP_USER` differing from the Kerberos short name is the usual cause |
| Principal mapped to the wrong user name | `sasl.kerberos.principal.to.local.rules` of the Kafka service must turn `user@REALM` into `user`, otherwise the `{USER}-*` policies do not match |
| Producer ran twice | Messages are duplicated and the lab counts (1, 15, 5, 21) no longer match; delete group and topic and start again (lab troubleshooting). The check accepts 21 or more |
| Console consumer ends with a timeout error | Normal for `--timeout-ms` (stretch 1); not an error of the lab |
| Reset fails (group not empty) | A consumer of the group is still running; stop it |
| Topic deletion pending | `delete.topic.enable` is on by default; a deleted topic needs some seconds before it can be created again |

## Admin

[setup/setup.sh](../setup/setup.sh) creates the shared topic `grid-measurements` (3 partitions) and loads the 15 sample rows, keyed by station. Run it with the ticket of a Kafka admin; it does nothing when the topic already exists. [setup/verify.sh](../setup/verify.sh) reads the 15 messages back. [setup/teardown.sh](../setup/teardown.sh) deletes the shared topic only. Policies: see the Ranger README, module 15.

## After module

Kafka is the entry point for streaming sensor data. Landing the topic data on HDFS or into an Iceberg table (Spark Structured Streaming, NiFi) builds on modules 06 and 07; it is not part of this basic lab.
