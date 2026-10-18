# Module 02 — Basics: YARN

Resource management for the grid monitoring use case: submit batch jobs that read the same HDFS files you explored in module 01, then follow applications through queues, status, and logs on the cluster.

**Estimated time:** ~80 minutes (core ~65 min + optional section and stretch)

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Module [01-basics-hdfs](../01-basics-hdfs/README.md) complete — especially `/user/${WORKSHOP_USER}/sample-landisgyr-data.csv` and a valid Kerberos ticket (`WORKSHOP_USER` + `kinit`)

## Learning goals

After this module you can:

- Describe how ResourceManager and NodeManagers relate to running engines (MapReduce, Tez, Spark)
- List cluster nodes and interpret queue / capacity scheduler basics
- Submit MapReduce, Tez, and Spark applications on YARN against workshop data
- Find the ApplicationMaster of a running application and explain what it does
- Compare the same job on MapReduce and Tez by elapsed time, containers, and resource allocation
- Explain why an application stays `ACCEPTED` or waits at 0% when its container requests do not fit
- Track application state with the YARN CLI and retrieve container logs
- Relate YARN failures (rejected, failed, killed) to what you will see in Hive and Spark labs

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | YARN vs HDFS; containers; queues; app lifecycle |
| Core lab | [lab/lab.md](lab/lab.md) sections 1–9 |
| Optional | [lab/lab.md](lab/lab.md) section 10 (requests that do not fit) and stretch tasks |
| Self-check | `./02-basics-yarn/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question talking points, jar paths  
- [trainer/demos.md](trainer/demos.md) — RM UI walk-through, queue drama, failed app (trainer-only)

## Admin (before session)

```bash
./00-setup/admin/bootstrap.sh
./02-basics-yarn/setup/setup.sh
./02-basics-yarn/setup/verify.sh
```

(HDFS module setup from module 01 should already be in place.)

## Next module

[03-basics-hive](../03-basics-hive/README.md)
