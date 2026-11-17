# Module 15 — Basics: Kafka (command line, Kerberos)

How continuously arriving measurements from transformer stations could enter the grid monitoring platform: you create your one personal topic (named like you), produce the smart-meter sample into it, consume it live and as a consumer group, and see where authentication (Kerberos) ends and authorization (Ranger) begins. Everything runs with the Kafka command-line tools on the edge node and your Kerberos ticket; there is no UI part.

**Estimated time:** ~55 minutes (core ~50 min + stretch).

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Your Kerberos user name and password (you run `kinit` in section 0)
- Broker host name and port of the Kerberos/TLS listener from your handout (`KAFKA_BOOTSTRAP`)
- Kafka command-line tools (`kafka-topics`, `kafka-console-producer`, …) on the edge node

## Learning goals

After this module you can:

- Configure a Kafka client for Kerberos (`SASL_SSL`, `GSSAPI`, ticket cache) without a password or keytab in a file
- Create a topic with partitions and replicas, and read its layout (leader, replicas, ISR)
- Produce keyed messages and explain why the same key always lands in the same partition
- Consume live and from the beginning, and explain why consuming does not delete messages
- Read consumer group state (current offset, log end offset, lag) and reset a group to re-read data
- Set a per-topic retention and explain the difference between Kerberos (who you are) and Ranger (what you may do)

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Topic, partition, offset, key; brokers and replication; consumer groups; Kerberos login of a Kafka client; Ranger for topics and groups |
| Core lab | [lab_basics_kafka.md](lab/lab_basics_kafka.md) sections 0–6 |
| Stretch | [lab_basics_kafka.md](lab/lab_basics_kafka.md) stretch (single partition, adding partitions, producer throughput, optional UI) |
| Self-check | `./15-basics-kafka/lab/check.sh`, then the clean-up at the end of the lab |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question answers, pitfalls  
- [trainer/demos.md](trainer/demos.md) — Kerberos debug output, two consumers in one group, killing a broker (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./15-basics-kafka/setup/setup.sh
./15-basics-kafka/setup/verify.sh
```

(Needs the **Kafka** service with a `SASL_SSL` listener, `KAFKA_BOOTSTRAP` in `config.env`, and a Kerberos ticket of a Kafka admin before `setup.sh` and `verify.sh`. Ranger: Kafka policies for personal topics and consumer groups, read-only on the shared topic — see [ranger README](../00-setup/admin/ranger/README.md).)

## Next module

[01-basics-kerberos](../01-basics-kerberos/README.md) (the ticket behind every command here) or the module list in the [root README](../README.md)

---
*The generation of these labs was supported by AI.*
