# HDFS hands-on lab

Run sections in order. Replace paths if your `WORKSHOP_ROOT` differs (see `config.env`).

```bash
kinit <your_user>
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export HDFS_LAB="${WORKSHOP_ROOT}/01-hdfs/lab"
```

---

## 1. Orient — workshop data

**Goal:** See how use-case files are stored before Hive or Spark touch them.

```bash
hdfs dfs -ls "${WORKSHOP_ROOT}"
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
hdfs dfs -du -h "${WORKSHOP_ROOT}/data"
hdfs dfs -cat "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" | head -5
hdfs dfs -tail "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"
```

**Check question:** Which columns appear in the Landis&Gyr sample? How is that different from a relational row stored only in Oracle?

**Expected output:** TODO: capture on cluster

Optional: open **Hue → File Browser** and browse to the same paths.

---

## 2. Personal workspace

**Goal:** Create `/user/$USER` and copy small workshop files (not the 192 MB demo file).

```bash
hdfs dfs -mkdir -p "/user/${USER}"
hdfs dfs -put /etc/hosts "/user/${USER}/hosts"
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "/user/${USER}/"
hdfs dfs -cp "${HDFS_LAB}/dummy.txt" "/user/${USER}/"
hdfs dfs -ls -h "/user/${USER}"
```

**Expected output:** TODO: capture on cluster

---

## 3. Inspect files and directories

**Goal:** Read size, block count, replication, and directory summaries.

```bash
hdfs dfs -count -h "/user/${USER}"
hdfs dfs -stat "%n blocks=%b repl=%r owner=%o" "/user/${USER}/sample-landisgyr-data.csv"
hdfs dfs -du -h "/user/${USER}"
hdfs dfs -du -s -h "/user/${USER}"
```

**Check question:** What is the difference between `-du` and `-du -s`? Why does total size with replication matter for capacity planning?

**Expected output:** TODO: capture on cluster

---

## 4. Blocks and replication

**Goal:** Connect block size to the shared 192 MB file (two 128 MB blocks at default block size).

Use the file in `${HDFS_LAB}` — do **not** copy it to your home directory.

```bash
hdfs dfs -ls -h "${HDFS_LAB}/bigfile_192mb.bin"
hdfs fsck "${HDFS_LAB}/bigfile_192mb.bin" -files -blocks -locations
hdfs dfs -stat "%n blocks=%b repl=%r" "${HDFS_LAB}/bigfile_192mb.bin"
```

Optional (if policy allows — discuss with trainer before running cluster-wide):

```bash
# hdfs dfs -setrep -w 2 "${HDFS_LAB}/bigfile_192mb.bin"
# hdfs dfs -du -s -h "${HDFS_LAB}/bigfile_192mb.bin"
```

**Check question:** How many blocks does `bigfile_192mb.bin` use? Where are replicas reported?

**Expected output:** TODO: capture on cluster

---

## 5. Trash — delete and recover

**Goal:** Delete `hosts`, find it under `.Trash`, restore it; then use `-skipTrash`.

```bash
hdfs dfs -rm "/user/${USER}/hosts"
hdfs dfs -ls -R "/user/${USER}/.Trash/Current"
```

Restore (path may include `/user/${USER}` under `.Trash/Current`):

```bash
TRASH_PATH="$(hdfs dfs -ls -R "/user/${USER}/.Trash/Current" | awk '/hosts$/{print $NF; exit}')"
echo "Restoring from: ${TRASH_PATH}"
hdfs dfs -mv "${TRASH_PATH}" "/user/${USER}/hosts"
hdfs dfs -cat "/user/${USER}/hosts" | head -3
```

Permanent delete:

```bash
hdfs dfs -rm -skipTrash "/user/${USER}/dummy.txt"
hdfs dfs -ls "/user/${USER}/dummy.txt" 2>&1 || true
hdfs dfs -ls -R "/user/${USER}/.Trash/Current" 2>/dev/null | grep dummy || echo "dummy.txt not in trash (expected)"
```

**Expected output:** TODO: capture on cluster

---

## 6. Download and append

**Goal:** Round-trip a file to the edge node and append locally sourced lines.

```bash
hdfs dfs -get "/user/${USER}/sample-landisgyr-data.csv" "/tmp/sample-landisgyr-data.csv.${USER}"
wc -l "/tmp/sample-landisgyr-data.csv.${USER}"
echo "# appended from edge node" >> "/tmp/sample-landisgyr-data.csv.${USER}"
hdfs dfs -appendToFile "/tmp/sample-landisgyr-data.csv.${USER}" "/user/${USER}/sample-landisgyr-data.csv"
hdfs dfs -tail "/user/${USER}/sample-landisgyr-data.csv"
```

**Expected output:** TODO: capture on cluster

---

## 7. Permissions and access denial

**Goal:** Read directory permissions; attempt to read the trainer `secret` path.

```bash
hdfs dfs -ls -d "/user/${USER}"
hdfs dfs -chmod 750 "/user/${USER}"
hdfs dfs -ls -d "${WORKSHOP_ROOT}/01-hdfs/secret"
hdfs dfs -cat "${WORKSHOP_ROOT}/01-hdfs/secret/secret.txt"
```

The last command should **fail** for participants (POSIX and/or Ranger).

**Check question:** Who owns the secret directory? Why is deny-by-default important for grid operational data?

**Expected output:** TODO: capture on cluster

---

## Stretch (optional)

```bash
hdfs dfs -getmerge "${WORKSHOP_ROOT}/data/awattar/" "/tmp/awattar-merged.${USER}.csv"
hdfs dfs -checksum "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
```

- Hue: upload a small text file to `/user/${USER}` and download it again.  
- Knox/NameNode UI: locate block information for the big file (trainer URL).

---

## Self-check

```bash
./01-basics-hdfs/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
