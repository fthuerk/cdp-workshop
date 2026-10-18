# Trainer notes — Module 01 HDFS

## Suggested timing (~75 min)

| Minutes | Activity |
|---------|----------|
| 0–15 | CDP storage role; NameNode/DataNode; blocks & replication (whiteboard) |
| 15–20 | Demo Hue File Browser on `data/landisgyr` |
| 20–50 | Participants: lab sections 1–5 (monitor room) |
| 50–60 | Section 6 append; section 7 permissions |
| 60–65 | Live demo: [demos.md](demos.md) sections 1–5, one block at a time |
| 65–75 | Stretch / Q&A; `check.sh` |

## Talking points

- **Use case:** CSVs in `data/` are the same files Hive will register as external tables — no duplicate toy dataset.  
- **Replication:** default RF=3 in prod; workshop big file is for block math (192 MB → 2 blocks @ 128 MB).  
- **Trash:** enterprise clusters often enable trash with retention; `-skipTrash` is irreversible.  
- **Security:** POSIX on secret dir is baseline; Ranger adds fine-grained policies for multi-tenant clusters.

## Demos (trainer only)

From an edge node, follow [demos.md](demos.md) section by section (participant `kinit` for section 1; `source lib/admin_auth.sh` before quota and snapshots).

## Pitfalls observed in dry runs (local review)

| Issue | Mitigation |
|-------|------------|
| Participants `cat` glob including binary/JAR | Lab copies only `dummy.txt` + CSV |
| Quota demo no-op | Setup uses **1m** space quota on `quota_reached` |
| Everyone reads secret | `chmod 700` + optional Ranger deny |
| Trash restore skipped | Lab includes explicit `-mv` from `.Trash/Current` |

## Expected outputs

Lab markdown blocks marked **TODO: capture on cluster** — replace after one participant dry run and paste into `lab/lab.md` or keep in an internal runbook.

## After module

Preview YARN: Hive/Spark jobs in later modules **store and read** the same HDFS paths participants explored today.
