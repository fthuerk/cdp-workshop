# YARN lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal provided by your instructor (`user@REALM`).

## `Input path does not exist`

All three jobs read the shared text file. Check that it and the Spark script exist:

```bash
hdfs dfs -ls "${YARN_LAB}/input" "${YARN_LAB}/assets"
```

If a file is missing, ask your instructor to run the module setup.

## `Output directory ... already exists`

MapReduce, Tez, and Spark refuse to write into an existing output path. Remove it and resubmit:

```bash
hdfs dfs -rm -r -skipTrash "/user/${WORKSHOP_USER}/wordcount-mr"
hdfs dfs -rm -r -skipTrash "/user/${WORKSHOP_USER}/wordcount-tez"
hdfs dfs -rm -r -skipTrash "/user/${WORKSHOP_USER}/linecount-spark"
```

## An example JAR is not found

This affects `hadoop-mapreduce-examples.jar` and `tez-examples-*.jar`. The parcel path differs on your cluster. Ask your instructor for the correct JAR location and use it in the same command. List the usual places with:

```bash
ls /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/ | grep examples
ls /opt/cloudera/parcels/CDH/lib/tez/bin/
```

## The many-small-files folder is missing or empty

Check `hdfs dfs -count "${YARN_LAB}/input-many"`. If it does not exist, ask your instructor to run the module setup.

## The first Tez run is much slower than MapReduce

Expected. A cold Tez job starts its ApplicationMaster and distributes the Tez libraries (about 1 GB) to the nodes first. Run it a second time — that is part of the exercise.

## Tez: `ClassNotFoundException` or `NoClassDefFoundError`

The Tez jars are not on your client classpath. Run the `export HADOOP_CLASSPATH=…` line from lab section 6 in the **same terminal** before `yarn jar` — it is not remembered in a new terminal.

## Tez: job fails while starting the ApplicationMaster

The Tez configuration did not point to the Tez libraries for the containers (`tez.lib.uris`). Check that `/opt/cloudera/parcels/CDH/lib/tez/conf` is part of `HADOOP_CLASSPATH`, then ask your instructor.

## Application stays in `ACCEPTED`

YARN has no free capacity in your queue yet. Check:

```bash
yarn node -list
yarn queue -status root.default
```

If nodes are `RUNNING` and the job is still waiting after a few minutes, ask your instructor — the queue or the cluster may be full.

## `yarn logs` returns nothing or `Permission denied`

- Wait a minute after the application finishes; logs are aggregated afterwards.  
- Use the full `application_…` ID from `yarn application -list`.  
- Only the submitting user can read their logs — check `klist` and `WORKSHOP_USER`.

## `yarn container -list` is empty

Container listings only work while the application is running. Start a longer `pi` job (raise the second number) and run the command while it is in state `RUNNING`.

## Leftover `QuasiMonteCarlo_…` directories in your home

Killed or failed `pi` runs leave their temporary directory behind. Remove them:

```bash
hdfs dfs -ls "/user/${WORKSHOP_USER}"
hdfs dfs -rm -r -skipTrash "/user/${WORKSHOP_USER}/<QuasiMonteCarlo-directory>"
```

## My oversized job is still waiting

Kill it so it does not block your queue: `yarn application -kill "<application-id>"`. List your own applications with `yarn application -list -appStates ACCEPTED,RUNNING`.

## `yarn logs -show_application_log_info` prints no containers

The application must be `FINISHED` and its logs aggregated (wait a minute). If the option is not recognized on your client version, list containers in the ResourceManager UI instead (application → attempt → containers).

## Spark: `python` or `pyspark` errors

`spark-submit` must be on your PATH on the edge node. If your cluster needs a specific Python, your instructor will give you an `export PYSPARK_PYTHON=…` line.

## Spark: script not found

The shared script is missing. Instructor: run [setup/setup.sh](../setup/setup.sh) with `WORKSHOP_LOCAL` pointing at this repo on the edge node, then [setup/verify.sh](../setup/verify.sh).

## Hue Job Browser shows different applications

Confirm Hue user matches Kerberos principal (`WORKSHOP_USER` / edge login).
