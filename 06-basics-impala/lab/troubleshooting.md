# Impala lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal from your instructor (`user@REALM`).

## `impala-shell: could not connect` or `Connection refused`

- Run `klist`. Renew with `kinit "${WORKSHOP_USER}"` if the ticket expired.  
- Check `echo "${IMPALA_OPTS}"` — it must match the coordinator flags from your handout (often `-i hostname:21050`).  
- Ask your instructor whether Impala daemons are running.

## Beeline / Hive section: `GSS initiate failed`

Only needed for section 4. Verify `HS2_URL` from your handout and a valid ticket (`klist`).

## `AnalysisException: Could not resolve path` or `Table not found`

- Run `USE ws_<your_username>;` in Impala.  
- In section 1, the `LOCATION` in `CREATE TABLE` must be the full HDFS path to `${IMPALA_WORK}/meter` (no typos in `WORKSHOP_USER`).  
- If the table exists but counts are wrong after section 5, run `INVALIDATE METADATA impala_meter;`.

## `Permission denied: user=hive` when creating the table or querying

Table data must live under `${IMPALA_WORK}`, not only in your `/user/...` home. Ask your instructor to re-run module setup — it grants the `hive` user access to `${WORKSHOP_ROOT}/06-impala/work`.

## Ranger: `does not have privilege` on database or HDFS URL

Same pattern as the Hive module: policies on `ws_*` and on `${WORKSHOP_ROOT}/06-impala/work/*`. Ask your instructor.

## UPDATE / DELETE errors in section 4

**Expected** on the external table `impala_meter`. Do not treat them as failures. If Hive succeeds on `UPDATE` here, you are not on `impala_meter` or the table is transactional — check with `DESCRIBE FORMATTED impala_meter;` (`EXTERNAL=TRUE`, no `transactional=true`).

## Self-check: row count not 15000

- Redo section 1 copy from `${IMPALA_LAB}/scaled/meter-15k.csv`.  
- If you still have `extra-copy.csv` from section 5, remove it and `INVALIDATE METADATA impala_meter;`.  
- Shared scaled file missing: instructor runs `./06-basics-impala/setup/setup.sh`.

## Impala much slower than expected

Cluster load, cold caches, or running on a laptop VPN can flatten the Hive vs Impala gap. Compare **relative** time and whether Hive created a Tez app on YARN; absolute seconds are not graded.
