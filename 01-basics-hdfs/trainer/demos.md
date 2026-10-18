# Trainer live demos — HDFS

Run **one section at a time** on an edge node while participants watch. Paths match module setup under `${WORKSHOP_ROOT}/01-hdfs`.

```bash
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust from config.env
export HDFS_MODULE="${WORKSHOP_ROOT}/01-hdfs"
export HDFS_LAB="${HDFS_MODULE}/lab"
export HDFS_QUOTA="${HDFS_MODULE}/quota_reached"
export HDFS_SECRET="${HDFS_MODULE}/secret"
```

Setup must be done before the session: [setup/setup.sh](../setup/setup.sh).

---

## 1. Secret path — participant view

**Goal:** Show the same denial participants saw in [lab section 7](../lab/lab.md).

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

## Timing hint

See [notes.md](notes.md) for where these fit in the ~75 minute session (typically after lab sections 1–7).
