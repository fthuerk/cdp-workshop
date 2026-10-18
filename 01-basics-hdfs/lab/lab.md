# HDFS hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path.

Set your Kerberos identity and paths once for the whole lab. `WORKSHOP_USER` is the short name you use with `kinit` (same account as on the edge node). `HDFS_LAB` points at shared module files on HDFS, including the large block demo file.

```bash
# Your identity and Kerberos ticket
export WORKSHOP_USER=<your_username>
kinit "${WORKSHOP_USER}"

# Workshop paths on HDFS (adjust WORKSHOP_ROOT if needed)
export WORKSHOP_ROOT=/2026_cdp_workshop
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

`-ls` columns: permissions, replication, owner, group, size, date, path. `-du` columns: size, size including replicas, path.

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
# Create your home and upload a local file from the edge node
hdfs dfs -mkdir -p "/user/${WORKSHOP_USER}"
hdfs dfs -put /etc/hosts "/user/${WORKSHOP_USER}/hosts"

# Copy files within HDFS
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "/user/${WORKSHOP_USER}/"
hdfs dfs -cp "${HDFS_LAB}/dummy.txt" "/user/${WORKSHOP_USER}/"

# List the result
hdfs dfs -ls -h "/user/${WORKSHOP_USER}"
```

You should see `hosts`, the Landis&Gyr sample, and `dummy.txt`. The big block demo file stays under `${HDFS_LAB}`.

---

## 3. Inspect files and directories

**Goal:** Read size, block count, replication, and directory summaries.

HDFS reports both **logical file size** and **space with replication** — important when many replicas exist on disk.

Count entries under your home, then print a few metadata fields for one CSV:

```bash
hdfs dfs -count -h "/user/${WORKSHOP_USER}"
hdfs dfs -stat "%n size=%y repl=%r owner=%o" "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
```

`-count` prints no header. Columns: **directories, files, size, path** (e.g. `1  3  2.1 K  /user/your_name`). `-stat` prints the fields from your format string: name, size in bytes, replication, owner.

Compare per-file usage with one summary line for the whole directory:

```bash
hdfs dfs -du -h "/user/${WORKSHOP_USER}"
hdfs dfs -du -s -h "/user/${WORKSHOP_USER}"
```

`-du` also has no header. Columns: **file size, size including all replicas, path**. With `-s` you get one total line for the directory.

**Check question:** What is the difference between `-du` and `-du -s`? Why does total size with replication matter for capacity planning?

---

## 4. Blocks and replication

**Goal:** Connect block size to the shared 192 MB file (two 128 MB blocks at default block size), then change replication and see the effect on reported size.

Work on **`${HDFS_LAB}/bigfile_192mb.bin`** in place — do not copy it to your home directory.

Start with human-readable size, then `fsck` to see block boundaries and which DataNodes hold replicas:

```bash
hdfs dfs -ls -h "${HDFS_LAB}/bigfile_192mb.bin"
hdfs fsck "${HDFS_LAB}/bigfile_192mb.bin" -files -blocks -locations
hdfs dfs -stat "%n size=%y repl=%r block_size=%b" "${HDFS_LAB}/bigfile_192mb.bin"
```

In the `fsck` output, look for the number of blocks and the DataNodes listed for each block. `-stat` shows size, replication, and the block size in bytes (`%b`).

Lower replication to 2 and wait until the cluster applies it (`-w`). Compare summarized disk usage and replication in `-stat` before and after:

```bash
hdfs dfs -setrep -w 2 "${HDFS_LAB}/bigfile_192mb.bin"
hdfs dfs -du -s -h "${HDFS_LAB}/bigfile_192mb.bin"
hdfs dfs -stat "%n size=%y repl=%r block_size=%b" "${HDFS_LAB}/bigfile_192mb.bin"
```

`repl=` should now be 2, and the second `-du` column should shrink while the file size stays the same.

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

**Goal:** Round-trip a file to the edge node and append a new measurement row.

Pipelines often land late or corrected readings on an edge node before pushing them into HDFS. HDFS files cannot be edited in place, but you can append to the end.

First download the CSV (suffix with your username so shared edge nodes do not clash) and count its lines:

```bash
# Download the file and count its lines
hdfs dfs -get "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv" "/tmp/sample-landisgyr-data.csv.${WORKSHOP_USER}"
wc -l "/tmp/sample-landisgyr-data.csv.${WORKSHOP_USER}"
```

Create a small local file with one new reading that matches the CSV columns (the next 15-minute value for station `TS-305`), then append only that file to the HDFS copy:

```bash
# One new row in the same column layout as the CSV
echo "2026-01-15T09:15:00Z,TS-305,LG-TS-305-C,L3,266.5,52.1,228.3,413.9,0.975,50.00,84.8,OK,,ONLINE" > "/tmp/new-reading.${WORKSHOP_USER}.csv"

# Append it to the file in HDFS and look at the end
hdfs dfs -appendToFile "/tmp/new-reading.${WORKSHOP_USER}.csv" "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
hdfs dfs -tail "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
```

The last line of the HDFS file should be your `09:15` reading, and the file has one more row than your local download.

---

## 7. Permissions and access denial

**Goal:** Read directory permissions; try to read a protected file under the workshop `secret` path.

HDFS exposes POSIX-style permission bits on paths (and your cluster may also enforce Ranger policies).

Inspect your home directory entry, tighten permissions on your own tree (`750` — owner full, group read/execute, others none), then look at the workshop `secret` path without expecting read access:

```bash
# Your home directory: show, then restrict
hdfs dfs -ls -d "/user/${WORKSHOP_USER}"
hdfs dfs -chmod 750 "/user/${WORKSHOP_USER}"

# The protected directory and file
hdfs dfs -ls -d "${WORKSHOP_ROOT}/01-hdfs/secret"
hdfs dfs -cat "${WORKSHOP_ROOT}/01-hdfs/secret/secret.txt"
```

The permission string (e.g. `drwxr-x---`) reads: type, then `rwx` for owner, group, others. After `chmod 750` you should see `rwxr-x---`.

You should **not** be able to read `secret.txt` — expect permission denied (POSIX, Ranger, or both). That is how sensitive grid data should behave when you have no grant.

**Check question:** Who owns the secret directory? Why is deny-by-default important for grid operational data?

---

## Stretch (optional)

**Merge a dataset folder into one local file.** Data often arrives as many part files. `-getmerge` concatenates all files of an HDFS folder into a single file on the edge node, which is handy for a quick look with normal Linux tools:

```bash
hdfs dfs -getmerge "${WORKSHOP_ROOT}/data/awattar/" "/tmp/awattar-merged.${WORKSHOP_USER}.csv"
wc -l "/tmp/awattar-merged.${WORKSHOP_USER}.csv"
head -3 "/tmp/awattar-merged.${WORKSHOP_USER}.csv"
```

Compare the line count with the individual files in `hdfs dfs -ls` of that folder.

**Check whether two HDFS files are identical.** `-checksum` prints one fingerprint per file without reading it back to your terminal. Equal checksums mean equal content; this is how you verify copies (for example after a `distcp`). Output is `path  algorithm  checksum`.

Make a fresh copy of the CSV and compare it with the original and with your appended file from section 6:

```bash
# Fresh copy of the original
hdfs dfs -cp "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv" "/user/${WORKSHOP_USER}/landisgyr-copy.csv"

# Original vs. fresh copy
hdfs dfs -checksum "${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
hdfs dfs -checksum "/user/${WORKSHOP_USER}/landisgyr-copy.csv"

# Your appended file from section 6
hdfs dfs -checksum "/user/${WORKSHOP_USER}/sample-landisgyr-data.csv"
```

The first two checksums should match. The third should differ because you appended a row.

**Optional (UI):**

- Hue: upload a small text file to `/user/${WORKSHOP_USER}` and download it again.
- NameNode UI: locate block information for the big file (use the URL from your workshop handout).

---

## Self-check

From the repo root on the edge node, run the module check script (uses your Kerberos ticket and HDFS home):

```bash
./01-basics-hdfs/lab/check.sh
```

If something fails, see [troubleshooting.md](troubleshooting.md).
