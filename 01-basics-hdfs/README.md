# Module 01 — Basics: HDFS

Distributed storage for the grid monitoring use case: explore sample CSVs in `${WORKSHOP_ROOT}/data`, manage your own `/user/$USER` workspace, and understand blocks, replication, trash, and permissions.

**Estimated time:** ~75 minutes (core ~60 min + stretch)

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (`check_env.sh` passes)
- Valid Kerberos ticket: `kinit <your_user>`

## Learning goals

After this module you can:

- Navigate workshop data paths and relate them to Landis&Gyr / weather / market files  
- Perform create, copy, inspect, delete, and download operations safely  
- Interpret block locations, replication factor, and space with replicas  
- Recover files from `.Trash` and understand `-skipTrash`  
- Explain how POSIX permissions (and optional Ranger) affect access  

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | HDFS vs local FS, NameNode/DataNode, blocks, replication |
| Core lab | [lab/lab.md](lab/lab.md) sections 1–7 |
| Stretch | [lab/lab.md](lab/lab.md) stretch tasks |
| Self-check | `./01-basics-hdfs/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, demos, pitfalls  
- [trainer/demos.sh](trainer/demos.sh) — secret, quota, snapshot (trainer-only)  

## Admin (before session)

```bash
source lib/admin_auth.sh
./00-setup/admin/bootstrap.sh
./01-basics-hdfs/setup/setup.sh
./01-basics-hdfs/setup/verify.sh
```

## Next module

[02-basics-yarn](../README.md) (planned — see root README)
