# HDFS hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path.

Set your Kerberos identity and paths once for the whole lab. `WORKSHOP_USER` is the short name you use with `kinit` (same account as on the edge node). `HDFS_LAB` points at shared module files on HDFS, including the large block demo file.

```bash
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"
export WORKSHOP_ROOT=/2026_cdp_workshop   # adjust if needed
export HDFS_LAB="${WORKSHOP_ROOT}/01-hdfs/lab"
```

All file operations use the `hdfs dfs` subcommand — the same verbs you would use on a local shell (`-ls`, `-cat`, `-cp`), but paths refer to the cluster filesystem.

---

## 1. Orient — workshop data

**Goal:** See how use-case files are stored before Hive or Spark touch them.

The workshop keeps read-only sample data under `${WORKSHOP_ROOT}/data`. You will reuse these paths in later modules when you define tables and jobs.

List the workshop root and the dataset folders, then check how much space the samples use:

```bash
hdfs dfs -ls "${WORKSHOP_ROOT}"
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
hdfs dfs -du -h "${WORKSHOP_ROOT}/data"
```

Peek at two representative files: smart-meter CSV (start of file) and operator weather (end of file — useful when files are append-only or you want the latest rows):

```bash
hdfs dfs -cat "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" | head -5
hdfs dfs -tail "${WORKSHOP_ROOT}/data/operator_weather/sample-operator-weather.csv"
```

**Check question:** Which columns appear in the Landis&Gyr sample? How is that different from a relational row stored only in Oracle?

Optional: open **Hue → File Browser** and browse to the same paths.

---

## 2. Personal workspace

**Goal:** Create `/user/${WORKSHOP_USER}` and copy small workshop files (not the 192 MB demo file).

Your HDFS home is where you can read and write during the workshop. Create it if it does not exist yet.

Upload a tiny file from the edge node (`-put`), copy workshop samples into your home (`-cp` within HDFS), then list what you have:

```bash
hdfs dfs -mkdir -p "/user/${WORKSHOP_USER}"
hdfs dfs -put /etc/hosts "/user/${WORKSHOP_USER}/hosts"
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "/user/${WORKSHOP_USER}/"
hdfs dfs -cp "${HDFS_LAB}/dummy.txt" "/user/${WORKSHOP_USER}/"
hdfs dfs -ls -h "/user/${WORKSHOP_USER}"
```

You should see `hosts`, the Landis&Gyr sample, and `dummy.txt`. The big block demo stays under `${HDFS_LAB}` so everyone shares one copy.

---

## 3. Inspect files and directories

**Goal:** Read size, block count, replication, and directory summaries.

HDFS reports both **logical file size** and **space with replication** — important when many replicas exist on disk.

Count files and directories under your home, then inspect one CSV (name, block count, replication factor, owner):

```bash
hdfs dfs -count -h "/user/${WORKSHOP_USER}"
hdfs dfs -stat "%n blocks=%b repl=%r owner=%o" "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
```

Compare per-file usage with a single summary line for the whole directory (`-du` vs `-du -s`):

```bash
hdfs dfs -du -h "/user/${WORKSHOP_USER}"
hdfs dfs -du -s -h "/user/${WORKSHOP_USER}"
```

**Check question:** What is the difference between `-du` and `-du -s`? Why does total size with replication matter for capacity planning?

---

## 4. Blocks and replication

**Goal:** Connect block size to the shared 192 MB file (two 128 MB blocks at default block size), then change replication and see the effect on reported size.

Work on **`${HDFS_LAB}/bigfile_192mb.bin`** in place — do not copy it to your home directory.

Start with human-readable size, then `fsck` to see block boundaries and which DataNodes hold replicas:

```bash
hdfs dfs -ls -h "${HDFS_LAB}/bigfile_192mb.bin"
hdfs fsck "${HDFS_LAB}/bigfile_192mb.bin" -files -blocks -locations
hdfs dfs -stat "%n blocks=%b repl=%r" "${HDFS_LAB}/bigfile_192mb.bin"
```

Lower replication to 2 and wait until the cluster applies it (`-w`). Compare summarized disk usage and replication in `-stat` before and after:

```bash
hdfs dfs -setrep -w 2 "${HDFS_LAB}/bigfile_192mb.bin"
hdfs dfs -du -s -h "${HDFS_LAB}/bigfile_192mb.bin"
hdfs dfs -stat "%n blocks=%b repl=%r" "${HDFS_LAB}/bigfile_192mb.bin"
```

**Check question:** How many blocks does `bigfile_192mb.bin` use? Where are replicas reported? How did `-du -s` change after `-setrep`?

---

## 5. Trash — delete and recover

**Goal:** Delete `hosts`, find it under `.Trash`, restore it; then use `-skipTrash`.

A normal `-rm` moves data into your user trash first (recovery window), unlike a local `rm`.

Remove `hosts`, then list trash recursively and note the full path where `hosts` appears — layout can include your username under `.Trash/Current`:

```bash
hdfs dfs -rm "/user/${WORKSHOP_USER}/hosts"
hdfs dfs -ls -R "/user/${WORKSHOP_USER}/.Trash/Current"
```

Move the file from that trash path back to your home and confirm content:

```bash
hdfs dfs -mv "<path-to-hosts-in-trash>" "/user/${WORKSHOP_USER}/hosts"
hdfs dfs -cat "/user/${WORKSHOP_USER}/hosts" | head -3
```

For `dummy.txt`, skip trash so the file is removed immediately — typical when you must free space or comply with retention rules:

```bash
hdfs dfs -rm -skipTrash "/user/${WORKSHOP_USER}/dummy.txt"
```

Confirm `dummy.txt` is gone from your home listing. Optionally look in `.Trash` again to compare with the earlier delete.

---

## 6. Download and append

**Goal:** Round-trip a file to the edge node and append locally sourced lines.

Pipelines often land corrections or small batches on an edge node before pushing bytes back into HDFS.

Copy the CSV to `/tmp` (suffix with your username so shared edge nodes do not clash), check line count, append a marker line locally, then extend the HDFS file without re-uploading the whole object:

```bash
hdfs dfs -get "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv" "/tmp/sample-landisgyr-data.csv.${WORKSHOP_USER}"
wc -l "/tmp/sample-landisgyr-data.csv.${WORKSHOP_USER}"
echo "# appended from edge node" >> "/tmp/sample-landisgyr-data.csv.${WORKSHOP_USER}"
hdfs dfs -appendToFile "/tmp/sample-landisgyr-data.csv.${WORKSHOP_USER}" "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
hdfs dfs -tail "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
```

The last lines of the HDFS file should include your appended comment.

---

## 7. Permissions and access denial

**Goal:** Read directory permissions; try to read a protected file under the workshop `secret` path.

HDFS exposes POSIX-style permission bits on paths (and your cluster may also enforce Ranger policies).

Inspect your home directory entry, tighten permissions on your own tree (`750` — owner full, group read/execute, others none), then look at the workshop `secret` path without expecting read access:

```bash
hdfs dfs -ls -d "/user/${WORKSHOP_USER}"
hdfs dfs -chmod 750 "/user/${WORKSHOP_USER}"
hdfs dfs -ls -d "${WORKSHOP_ROOT}/01-hdfs/secret"
hdfs dfs -cat "${WORKSHOP_ROOT}/01-hdfs/secret/secret.txt"
```

You should **not** be able to read `secret.txt` — expect permission denied (POSIX, Ranger, or both). That is how sensitive grid data should behave when you have no grant.

**Check question:** Who owns the secret directory? Why is deny-by-default important for grid operational data?

---

## Stretch (optional)

Merge many small files in one dataset folder into one local file (`-getmerge`), and show checksum metadata for a single file:

```bash
hdfs dfs -getmerge "${WORKSHOP_ROOT}/data/awattar/" "/tmp/awattar-merged.${WORKSHOP_USER}.csv"
hdfs dfs -checksum "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
```

- Hue: upload a small text file to `/user/${WORKSHOP_USER}` and download it again.  
- Knox/NameNode UI: locate block information for the big file (use the URL from your workshop handout).

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket and HDFS home):

```bash
./01-basics-hdfs/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
