# Impala lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal from your instructor (`user@REALM`).

## `impala-shell: could not connect` or `Connection refused`

- Run `klist`. Renew with `kinit "${WORKSHOP_USER}"` if the ticket expired.  
- Check `echo "${IMPALA_OPTS}"` — it must match the lab intro: `-i <host>:28000 --protocol=hs2-http -d default -k --ssl --ca_cert=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem`. Port 28000 needs `--protocol=hs2-http`.  
- Ask your instructor whether Impala daemons are running.

## Beeline / Hive section: `GSS initiate failed`

Only needed for section 4. Verify you have a valid ticket (`klist`) and that plain `beeline` connects on the edge node.

## `AnalysisException: Could not resolve path` or `Table not found`

- Run `USE <your_username>;` in Impala.  
- In section 1, create the table without a `LOCATION` clause and copy the CSV into `${IMPALA_EXT}/impala_meter` (no typos in `WORKSHOP_USER`), then run `REFRESH impala_meter;`.  
- If the table exists but counts are wrong after section 5, run `INVALIDATE METADATA impala_meter;`.

## `Permission denied: user=hive` when creating the table or querying

Table data must live in the default external folder `${IMPALA_EXT}/impala_meter` — do not create tables with a custom `LOCATION`. If the copy itself is denied, ask your instructor to check HDFS access on `${IMPALA_EXT}`.

## Ranger: `does not have privilege` on database or HDFS

Same pattern as the Hive module: policies on `{USER}` and read/write on `/warehouse/tablespace/external/hive/{USER}.db`. No URL policy is needed. Ask your instructor.

## UPDATE / DELETE errors in section 4

**Expected** on the external table `impala_meter`. Do not treat them as failures. If Hive succeeds on `UPDATE` here, you are not on `impala_meter` or the table is transactional — check with `DESCRIBE FORMATTED impala_meter;` (`EXTERNAL=TRUE`, no `transactional=true`).

## Self-check: row count not 15000

- Redo section 1 copy from `${IMPALA_LAB}/scaled/meter-15k.csv`.  
- If you still have `extra-copy.csv` from section 5, remove it and `INVALIDATE METADATA impala_meter;`.  
- Shared scaled file missing: instructor runs `./05-basics-impala/setup/setup.sh`.

## Impala much slower than expected

Cluster load, cold caches, or running on a laptop VPN can flatten the Hive vs Impala gap. Compare **relative** time and whether Hive created a Tez app on YARN; absolute seconds are not graded.
