# CDP workshop

Hands-on modules for Cloudera Data Platform, organized as a **sequential curriculum** (not tied to calendar days). Map modules to your schedule as needed.

**Use case:** combine smart-meter field trial data from transformer stations with operator weather stations, public weather/market feeds, and reference layers into a governed, repeatable data product.

## Quick start

| Role | Start here |
|------|------------|
| Participant | [00-setup](00-setup/README.md) → run `participant/check_env.sh` after `kinit` |
| Participant, no admin access to the platform | [00-setup](00-setup/README.md#path-b-no-trainer-access-to-the-platform-self-service) → run `00-setup/participant/setup.sh`, then use the `WORKSHOP_ROOT` it prints |
| Trainer / admin | Copy `config.env.example` → `config.env`, then [00-setup/admin](00-setup/admin/README.md) |

## Module catalog

| ID | Module | Track | Est. time | Status |
|----|--------|-------|-----------|--------|
| 00 | [Setup](00-setup/README.md) | — | 15 min | **Ready** |
| 01 | [Basics: Kerberos](01-basics-kerberos/README.md) | Basics | ~35 min | Draft (not yet dry-run on a cluster) |
| 02 | [Basics: HDFS](02-basics-hdfs/README.md) | Basics | ~75 min | **Ready** |
| 03 | [Basics: YARN](03-basics-yarn/README.md) | Basics | ~80 min | **Ready** |
| 04 | [Basics: Hive](04-basics-hive/README.md) | Basics | ~100 min | Draft (not yet dry-run on a cluster) |
| 05 | [Basics: Impala](05-basics-impala/README.md) | Basics | ~45 min | Draft (not yet dry-run on a cluster) |
| 06 | [Basics: Spark](06-basics-spark/README.md) | Basics | ~90 min | Draft (not yet dry-run on a cluster) |
| 07 | [Lakehouse: Iceberg](07-lakehouse-iceberg/README.md) | Lakehouse | ~120 min | Draft (not yet dry-run on a cluster) |
| 08 | [Basics: Oozie in Hue](08-basics-oozie/README.md) | Basics | ~70 min | Draft (not yet dry-run on a cluster) |
| 09 | [Basics: Spark via Livy](09-basics-livy/README.md) | Basics | ~90 min | Draft (not yet dry-run on a cluster) |
| I1 | [Instructor-led: Ranger](I1-basics-ranger/README.md) | Instructor-led | ~30 min | Draft (not yet dry-run on a cluster) |
| I2 | [Instructor-led: Atlas](I2-basics-atlas/README.md) | Instructor-led | ~20 min | Draft (not yet dry-run on a cluster) |
| 10 | [Advanced: Hive](10-advanced-hive/README.md) | Advanced | ~75 min | Draft (not yet dry-run on a cluster) |
| 11 | [Advanced: Oozie](11-advanced-oozie/README.md) | Advanced | ~110 min | Draft (not yet dry-run on a cluster) |
| 14 | [Basics: Data types across engines](14-basics-datatypes/README.md) | Basics | ~40 min | Draft (not yet dry-run on a cluster) |
| 12 | Advanced: Spark | Advanced | ~90 min | Planned |
| 13 | Advanced: Impala | Advanced | ~60 min | Planned |
| 20 | MVP: Full pipeline | MVP | ~120 min | Planned |

**Basics track:** Kerberos → HDFS → YARN → Hive → Spark → Impala  
**Spark access via REST:** `09` runs the Spark pipeline through Livy behind Knox (LDAP login), with `curl` and with a Jupyter notebook on your laptop  
**Lakehouse:** Iceberg tables in Hue/Impala (after Hive and Impala basics)  
**Orchestration:** Oozie: `08` is a Hue UI tour, `11` builds the same pipeline by hand (workflow XML, Hive and Spark actions, coordinators)  
**Instructor-led (`I1`, `I2`):** Ranger and Atlas are driven live by the trainer in the UI (policies and tags change while you watch), so they are numbered separately and can be dropped into any day  
**Advanced track:** Hive → Oozie → Spark → Impala (deeper patterns on the same use case)  
**MVP:** end-to-end pipeline with quality checks and governance touchpoints

See [docs/concept.md](docs/concept.md) for learning objectives, dependencies, and fallbacks.

**Slides:** modules with a slide deck are published together with an overview page of all labs on GitHub Pages (`https://<user>.github.io/<repo>/`). Decks live in [slides/](slides/README.md).

**Authors:** [docs/workshop-guidelines.md](docs/workshop-guidelines.md) (labs and modules) · [docs/simplicity.md](docs/simplicity.md) (scripts)

## Repository layout

```
config.env.example   # cluster-specific settings
lib/                 # common.sh, admin_auth.sh
data/samples/        # synthetic CSVs (uploaded to HDFS by bootstrap)
00-setup/            # shared cluster bootstrap
01-basics-kerberos/  # Kerberos lab + trainer (no setup needed; first lab)
02-basics-hdfs/      # lab + trainer + setup scripts
03-basics-yarn/      # YARN lab + setup scripts
04-basics-hive/      # Hive lab + trainer + setup scripts
10-advanced-hive/    # Advanced Hive lab (joins, window functions, complex types, WKT) + trainer
05-basics-impala/    # Impala lab + trainer + setup scripts
06-basics-spark/     # Spark lab + trainer + setup scripts
07-lakehouse-iceberg/ # Lakehouse lab (Iceberg in Hue/Impala) + trainer + setup scripts
08-basics-oozie/     # Oozie tour through Hue (workflow, coordinators, generated XML) + trainer
09-basics-livy/      # Spark via Livy (REST sessions and batches, local Jupyter notebook) + trainer + setup scripts
11-advanced-oozie/   # Oozie by hand (workflows, actions, coordinators) + trainer + example applications
14-basics-datatypes/ # Data types and functions compared across Hive, Impala, Spark + trainer + setup scripts
I1-basics-ranger/    # Ranger lab (allow, deny, masking, row filter) + trainer + setup scripts
I2-basics-atlas/     # Atlas UI lab (metadata, lineage, tags, glossary) + trainer
slides/              # Slidev decks + build-site.mjs (overview page for GitHub Pages)
docs/concept.md              # curriculum concept
docs/workshop-guidelines.md  # how to author labs and modules
```

## On the cluster

1. Clone or unpack this repo on an edge node → set `WORKSHOP_LOCAL` in `config.env`.
2. Admin: `00-setup/admin/bootstrap.sh`, then per-module `setup/setup.sh` (e.g. `02-basics-hdfs`, `06-basics-spark`), then each module’s `verify.sh`.
3. Participants: read each module’s lab markdown (for example `lab/lab_basics_hdfs.md`) and run commands with a personal Kerberos principal.

Labs define success through outcomes and `lab/check.sh`, not fixed sample transcripts.

---
*The generation of these labs was supported by AI.*
