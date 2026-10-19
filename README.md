# CDP workshop

Hands-on modules for Cloudera Data Platform, organized as a **sequential curriculum** (not tied to calendar days). Map modules to your schedule as needed.

**Use case:** combine smart-meter field trial data from transformer stations with operator weather stations, public weather/market feeds, and reference layers into a governed, repeatable data product.

## Quick start

| Role | Start here |
|------|------------|
| Participant | [00-setup](00-setup/README.md) → run `participant/check_env.sh` after `kinit` |
| Trainer / admin | Copy `config.env.example` → `config.env`, then [00-setup/admin](00-setup/admin/README.md) |

## Module catalog

| ID | Module | Track | Est. time | Status |
|----|--------|-------|-----------|--------|
| 00 | [Setup](00-setup/README.md) | — | 15 min | **Ready** |
| 01 | [Basics: HDFS](01-basics-hdfs/README.md) | Basics | ~75 min | **Ready** |
| 02 | [Basics: YARN](02-basics-yarn/README.md) | Basics | ~80 min | **Ready** |
| 03 | [Basics: Hive](03-basics-hive/README.md) | Basics | ~120 min | Draft (not yet dry-run on a cluster) |
| 04 | Basics: Spark | Basics | ~90 min | Planned |
| 05 | [Basics: Impala](05-basics-impala/README.md) | Basics | ~45 min | Draft (not yet dry-run on a cluster) |
| 10 | Advanced: Hive | Advanced | ~90 min | Planned |
| 11 | Advanced: Spark | Advanced | ~90 min | Planned |
| 12 | Advanced: Impala | Advanced | ~60 min | Planned |
| 13 | Advanced: Oozie | Advanced | ~75 min | Planned |
| 20 | MVP: Full pipeline | MVP | ~120 min | Planned |

**Basics track:** HDFS → YARN → Hive → Spark → Impala  
**Advanced track:** Hive → Spark → Impala → Oozie (deeper patterns on the same use case)  
**MVP:** end-to-end pipeline with quality checks and governance touchpoints

See [docs/concept.md](docs/concept.md) for learning objectives, dependencies, and fallbacks.

**Authors:** [docs/workshop-guidelines.md](docs/workshop-guidelines.md) (labs and modules) · [docs/simplicity.md](docs/simplicity.md) (scripts)

## Repository layout

```
config.env.example   # cluster-specific settings
lib/                 # common.sh, admin_auth.sh
data/samples/        # synthetic CSVs (uploaded to HDFS by bootstrap)
00-setup/            # shared cluster bootstrap
01-basics-hdfs/      # lab + trainer + setup scripts
02-basics-yarn/      # YARN lab + setup scripts
03-basics-hive/      # Hive lab + trainer + setup scripts
05-basics-impala/    # Impala lab + trainer + setup scripts
docs/concept.md              # curriculum concept
docs/workshop-guidelines.md  # how to author labs and modules
```

## On the cluster

1. Clone or unpack this repo on an edge node → set `WORKSHOP_LOCAL` in `config.env`.
2. Admin: `00-setup/admin/bootstrap.sh`, then `01-basics-hdfs/setup/setup.sh`, then each module’s `verify.sh`.
3. Participants: read module `lab/lab.md` and run commands with a personal Kerberos principal.

Labs define success through outcomes and `lab/check.sh`, not fixed sample transcripts.
