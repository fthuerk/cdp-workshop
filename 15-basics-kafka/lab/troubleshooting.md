# Kafka lab — troubleshooting

## `LoginException` / `Failed to create new KafkaAdminClient` / "asked for a password"

You have no valid Kerberos ticket (or the tool cannot read it). In section 0 this is the expected failure case; anywhere else:

- `klist` — is there a ticket for your user? If not, `kinit "${WORKSHOP_USER}"` (own block, nothing after it).
- The ticket expired: run `kinit` again.
- You skipped the `kinit` of section 0 (the failure case there is meant to run before it).
- Your shell has `KRB5CCNAME` pointing at another cache: `unset KRB5CCNAME`.
- Java tools can only read a **file** ticket cache. If HDFS commands work but Kafka does not, ask your instructor; the ticket cache type is the same problem for all Java clients.

## `Server not found in Kerberos database` / `Cannot locate default realm`

The client builds the service principal `kafka/<host>@<REALM>` from the broker host name you gave. Use the **full host name** (FQDN) from the handout in `KAFKA_BOOTSTRAP`, not an IP address, a short name or a load balancer alias.

## `Timed out waiting for a node assignment` / `Connection ... could not be established` / `Disconnected`

- Wrong port: the Kerberos/TLS listener (`SASL_SSL`) is often `9093`, plain `SASL_PLAINTEXT` is `9092`. Take the port from your handout.
- A tool prints `SSL handshake failed` or `PKIX path building failed`: the client does not trust the broker certificate. Ask your instructor.
- `security.protocol` in `${KAFKA_CONF}` must match the listener. Do not mix a `SASL_PLAINTEXT` port with `SASL_SSL`.

## `kafka-console-producer`: `Unrecognized option: --bootstrap-server` / `--producer.config`

Older clients (before Kafka 2.5) use `--broker-list` instead of `--bootstrap-server` for the producer. Use `--broker-list "${KAFKA_BOOTSTRAP}"` and keep `--producer.config`.

## Producer: `Unexpected error in InitProducerIdResponse` / `Cannot execute transactional method because we are in an error state`

The producer asked a broker for a producer ID (idempotent writes are on by default in Kafka clients 3.0 and newer) and the broker answered with an internal error, so nothing was sent. This is not a Kerberos or topic permission problem: in the broker log the Ranger Kafka plugin fails with `UnsupportedOperationException` in `RangerKafkaCheckAccess.authorizeByResourceType` (a bug of the plugin in some CDP versions). The lab turns idempotence off in `KAFKA_PRODUCE` (`--producer-property enable.idempotence=false`):

- `echo "${KAFKA_PRODUCE}"` — it must end with `enable.idempotence=false`. If it does not, repeat the exports from the top of the lab.
- If it still fails, ask your instructor and send the message and the time; the broker log of that time shows the real error.

## `GroupAuthorizationException: Not authorized to access group`

You may use only the consumer group named like you. Every consumer in the lab has `--group "${KAFKA_GROUP}"`; without that option the console consumer invents a group name (`console-consumer-<number>`) and Ranger refuses it. Check `echo "${KAFKA_GROUP}"`. If the right group is refused, the consumer-group policy is missing: ask your instructor.

## `TopicAuthorizationException` on your own topic

You may only use **one** topic, named exactly like your user name. Check `echo "${KAFKA_TOPIC}"`: if `WORKSHOP_USER` was empty or differs from your Kerberos name when you exported it, the name is wrong (creating another topic is refused). Set `WORKSHOP_USER` again and repeat the exports. On the shared topic `grid-measurements` the error is **expected for writing** (section 6).

## `TopicExistsException` / `InvalidReplicationFactorException`

- Topic exists: you have already created it; continue. (`--if-not-exists` in the lab avoids the message.)
- Replication factor larger than the number of brokers: use `--replication-factor 2` (or `1`) and tell your instructor.

## Consumer prints nothing and waits

- Section 2: the consumer starts before the producer and waits; send the data from terminal 1.
- Your group already read everything: it continues at its position and waits for new messages. Reset the group (section 4) or produce more messages.
- A group without a position that you start without `--from-beginning` only sees messages that arrive after it started.
- The consumer stops only after `--max-messages` messages. If fewer exist (for example you ran the producer once less than described) press Ctrl+C.

## Output has no partition or offset columns

Your client is older than 2.7 and ignores `print.partition`. Use `--property print.offset=true --property print.key=true`; you can still compare keys and offsets, and the stretch about partitions then uses `--partition 0` and the offsets instead.

## More than 16 or 21 messages in the topic

You ran a producer command twice. Kafka does not deduplicate. Delete your group and topic (see **Clean up** in the lab), wait half a minute, and redo sections 1–4. The topic has to be gone before you create it again.

## `Reset offsets` fails: group is not empty

A consumer of your group is still running (check terminal 2 and any other session). Stop it with Ctrl+C and repeat.

## Self-check fails

Each `[FAIL]` line names the lab section to redo. `Expected at least 21 messages` means the producer commands of sections 2 and 3 did not run to the end, or the group name differs from `${KAFKA_GROUP}`.
