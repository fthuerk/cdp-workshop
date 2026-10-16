# HDFS lab — troubleshooting

## `kinit: Client not found in Kerberos database`

Wrong username or realm. Use the principal provided by the trainer (`user@REALM`).

## `Permission denied` on `${WORKSHOP_ROOT}`

- Run `klist` — ticket expired?  
- Trainer: re-run [bootstrap](../../00-setup/admin/bootstrap.sh) and confirm you can `hdfs dfs -ls` as superuser then as participant.

## `mkdir /user/$USER` fails

Home directory creation may be disabled. Ask trainer to add you to `participants.txt` and re-run bootstrap, or use a personal subfolder under `${WORKSHOP_ROOT}/01-hdfs/public/${USER}` (if enabled).

## Trash restore path not found

Trash layout varies by CDP version. List recursively:

```bash
hdfs dfs -ls -R "/user/${USER}/.Trash"
```

Move from the path that ends with `/hosts`.

## `fsck` access denied on big file

You need read permission on `${WORKSHOP_ROOT}/01-hdfs/lab`. Trainer runs [setup/verify.sh](../setup/verify.sh).

## `setrep` rejected

Changing replication may require admin privileges or storage policies. Skip stretch `setrep` and discuss replication conceptually.

## Secret file readable when it should not be

Trainer: re-run [setup/setup.sh](../setup/setup.sh) for `chmod 700` on secret; confirm Ranger deny policy if used.

## Hue shows different paths than CLI

Confirm Hue user matches Kerberos principal (`USER` on edge node). Clear browser cache or re-login via Knox.
