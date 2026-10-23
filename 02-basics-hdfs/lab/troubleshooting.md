# HDFS lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal provided by the trainer (`user@REALM`).

## `Permission denied` on `${WORKSHOP_ROOT}`

- Run `klist` — ticket expired?  
- Trainer: re-run [bootstrap](../../00-setup/admin/bootstrap.sh) and confirm you can `hdfs dfs -ls` as superuser then as participant.

## `mkdir ${WORKSHOP_HOME}` fails

Home directory creation may be disabled. Ask trainer to add you to `participants.txt` and re-run bootstrap, or use a personal subfolder under `${WORKSHOP_ROOT}/02-hdfs/public/${USER}` (if enabled).

## Trash restore path not found

Trash layout varies by CDP version. List recursively:

```bash
hdfs dfs -ls -R "${WORKSHOP_HOME}/.Trash"
```

Move from the path that ends with `/hosts`.

## `fsck` access denied on big file

You need read permission on `${WORKSHOP_ROOT}/02-hdfs/lab`. Trainer runs [setup/verify.sh](../setup/verify.sh).

## `setrep` rejected

Changing replication on the shared big file may require extra HDFS permissions or storage policies. Ask the trainer to confirm module setup, or observe replication only with `-stat` / `fsck` and discuss the concept as a group.

## Secret file readable when it should not be

Trainer: re-run [setup/setup.sh](../setup/setup.sh) for `chmod 700` on secret; confirm Ranger deny policy if used.

## Hue shows different paths than CLI

Confirm Hue user matches Kerberos principal (`WORKSHOP_USER` / edge login). Clear browser cache or re-login via Knox.
