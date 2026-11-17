# Trainer demos — Module 15 Kafka

Optional live-only steps — not required for participants. Use your own user and the variables from the lab setup block.

## 1. Watch the Kerberos exchange (3 min)

Run a Kafka command with Java's Kerberos debug output. The room sees the service ticket request for `kafka/<broker-host>` that `klist` does not show (Java keeps service tickets in memory):

```bash
# Debug output of the Kerberos login and the service ticket request
KAFKA_OPTS="-Dsun.security.krb5.debug=true" kafka-topics ${KAFKA_ADMIN} --list 2>&1 | head -60
```

Look for the TGS request and the service name `kafka/...`. Ties back to module 01: the TGT (from `kinit`) is exchanged for a ticket for one service.

## 2. Two consumers in one group (5 min)

Start two consumers with the same `--group` in two terminals, on a topic with three partitions, while a third terminal produces. Each consumer gets some partitions. Show it with:

```bash
# Members and their partitions
kafka-consumer-groups ${KAFKA_ADMIN} --describe --group "${KAFKA_GROUP}" --members --verbose
```

Stop one consumer: the partitions move to the remaining one (**rebalance**). Start a third and a fourth: with three partitions the fourth gets nothing. Do not use the groups of the participants.

## 3. Kill the partition leader (needs admin rights)

Stop one broker role instance in Cloudera Manager while a producer runs. Show `kafka-topics --describe` before and after: the leader moves and the ISR list shrinks; the producer continues. Restart the broker and show the ISR growing back. Only with a cluster that can afford it.

## 4. Ranger audit live

Open the Kafka policy for `grid-measurements` in Ranger (consume and describe only), let a participant repeat the denied write of section 6, and open **Audit → Access**. Then add `publish` to the policy, let the participant repeat the write, and show the new audit line (remove it again and delete the extra test message by recreating the topic with `teardown.sh` and `setup.sh`). Shows the loop *policy → denial → audit* without any change on the Kafka side.
