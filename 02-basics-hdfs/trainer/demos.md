# Trainer live demos — HDFS

Run **one section at a time** on an edge node while participants watch. Paths match module setup under `${WORKSHOP_ROOT}/02-hdfs`.

```bash
export WORKSHOP_ROOT="${WORKSHOP_ROOT:-/2026_cdp_workshop}"   # adjust from config.env
export HDFS_MODULE="${WORKSHOP_ROOT}/02-hdfs"
export HDFS_LAB="${HDFS_MODULE}/lab"
export HDFS_QUOTA="${HDFS_MODULE}/quota_reached"
export HDFS_SECRET="${HDFS_MODULE}/secret"
```

Setup must be done before the session: [setup/setup.sh](../setup/setup.sh).

---

## 1. Secret path — participant view

**Goal:** Show the same denial participants saw in [lab section 7](../lab/lab_basics_hdfs.md).

Use a **workshop participant** ticket (not `hdfs`):

```bash
kinit <participant_user>
klist
hdfs dfs -ls -d "${HDFS_SECRET}"
hdfs dfs -cat "${HDFS_SECRET}/secret.txt"
```

The `cat` should **fail** (POSIX `700` and/or Ranger).

**Talking point:** Operational grid data stays deny-by-default; Ranger adds policy on top of POSIX.

**Expected output:** TODO: capture on cluster

---

## 2. Admin ticket for quota and snapshots

**Goal:** Authenticate as HDFS superuser for `dfsadmin` and snapshot demos.

From the repo on a CM-managed edge node:

```bash
cd "${WORKSHOP_LOCAL}"    # e.g. clone path from config.env
source lib/admin_auth.sh
klist
```

You should see an `hdfs/...` principal (not `HTTP/...`).

**Expected output:** TODO: capture on cluster

---

## 3. Space quota — set and inspect

**Goal:** Show how admins cap directory space; setup uses **1m** so uploads fail predictably.

Re-apply quota live (safe to repeat between cohorts):

```bash
hdfs dfsadmin -clrSpaceQuota "${HDFS_QUOTA}"
hdfs dfsadmin -setSpaceQuota 1m "${HDFS_QUOTA}"
hdfs dfs -count -q "${HDFS_QUOTA}"
```

**Check question:** What do the quota columns mean in `hdfs dfs -count -q`?

**Expected output:** TODO: capture on cluster

---

## 4. Space quota — upload violation

**Goal:** Trigger a quota error on write.

Still as **hdfs** (or any user with write permission on `quota_reached`):

```bash
hdfs dfs -put -f /etc/hosts "${HDFS_QUOTA}/hosts-quota-test"
```

This should **fail** with a quota-related message.

Optional cleanup before the next cohort:

```bash
hdfs dfs -rm -skipTrash "${HDFS_QUOTA}/hosts-quota-test" 2>/dev/null || true
```

**Expected output:** TODO: capture on cluster

---

## 5. Snapshots on the lab directory

**Goal:** Enable snapshots, take one, list snapshot contents (admin only).

```bash
hdfs dfsadmin -allowSnapshot "${HDFS_LAB}"
hdfs dfs -createSnapshot "${HDFS_LAB}" "demo-snap-$(date +%H%M)"
hdfs dfs -ls "${HDFS_LAB}/.snapshot" 2>/dev/null || hdfs dfs -ls "${HDFS_LAB}/.snapshots"
```

Optional narrative (do not run unless you want a live restore):

1. Delete `dummy.txt` from `${HDFS_LAB}`.
2. Copy it back from the snapshot path shown in the listing above.

If snapshots are disabled cluster-wide, skip this section and mention HDFS snapshots in slides only.

**Expected output:** TODO: capture on cluster

---

## 6. Find a block on a DataNode and lose it

**Goal:** Show that a file is just block files on DataNode disks, and that HDFS heals itself when a replica disappears.

Needs SSH/root access to a DataNode host and the ability to restart a DataNode (Cloudera Manager). Use the shared big file; do this **after** participants finished lab section 4, and not during a lab run.

**Step 1 — Find the blocks and their locations** (any edge node, `hdfs` or participant ticket):

```bash
hdfs fsck "${HDFS_LAB}/bigfile_192mb.bin" -files -blocks -locations
```

Pick the first block. In the output, note:

- the block ID, e.g. `blk_1073741830_1006` (the number after `blk_` is what you search for)
- the block pool, e.g. `BP-123456-10.0.0.1-1700000000000`
- the DataNode addresses holding replicas, e.g. `DatanodeInfoWithStorage[10.0.0.11:9866,...]`

**Step 2 — Log in to one of those DataNodes** and find the block file:

```bash
ssh <datanode_host>
hdfs getconf -confKey dfs.datanode.data.dir    # may show a CM placeholder; otherwise use the CM config page
find /dfs/dn -name 'blk_1073741830*'            # replace /dfs/dn with a data dir, and the ID with yours
```

You get two files: `blk_<id>` (the data) and `blk_<id>_<genstamp>.meta` (checksums), under `.../current/BP-.../current/finalized/subdirN/subdirM/`. Show the size (about 128 MB for the first block) with `ls -lh`, and `head -c 200` to show it is raw file content.

**Step 3 — Delete the replica on this one DataNode:**

```bash
rm <path>/blk_1073741830 <path>/blk_1073741830_1006.meta
```

The file is still fully readable, because the other replicas exist:

```bash
hdfs dfs -cat "${HDFS_LAB}/bigfile_192mb.bin" | wc -c
```

**Step 4 — Make the NameNode notice.** The DataNode only learns about the missing file through its directory scanner (default every 6 hours) or when it restarts and sends a full block report. For the demo, restart that DataNode in Cloudera Manager (HDFS → Instances → DataNode → Restart).

**Step 5 — Watch HDFS heal:**

```bash
hdfs fsck "${HDFS_LAB}/bigfile_192mb.bin" -files -blocks -locations
```

Right after the restart you should see `Under replicated` (fewer replicas than the replication factor). Repeat after a minute or two: the NameNode has copied the block to another DataNode, `Under replicated blocks` is back to 0, and the location list shows a new node. Run `hdfs fsck / | tail -20` for the cluster summary (`Status: HEALTHY`).

**Talking points:**

- Block = ordinary file on the DataNode's local file system; the NameNode only keeps the mapping file → blocks → DataNodes.
- With replication 3, losing one replica costs nothing; with replication 1 the block would be `MISSING` and the file corrupt.
- Connects to lab section 4: lowering replication with `-setrep` reduces this safety margin.

If you lowered replication in the lab (`-setrep -w 2`), the numbers above use 2 instead of 3. Optionally reset it afterwards:

```bash
hdfs dfs -setrep -w 3 "${HDFS_LAB}/bigfile_192mb.bin"
```

---

## Timing hint

See [notes.md](notes.md) for where these fit in the ~75 minute session (typically after lab sections 1–7).
