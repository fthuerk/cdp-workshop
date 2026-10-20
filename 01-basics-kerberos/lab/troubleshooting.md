# Kerberos lab — troubleshooting

## `klist` shows a ticket, but `hdfs` says "No valid credentials provided"

Your tool is not looking where your ticket is.

- Run `echo "${KRB5CCNAME}"`. If it points to a file you deleted, run `unset KRB5CCNAME` and `kinit "${WORKSHOP_USER}"`.
- Look at the first line of `klist` (`Ticket cache:`). If it starts with `KCM:` or `KEYRING:`, Java tools may not be able to read it. Use a file cache for the rest of the lab:

```bash
export KRB5CCNAME="FILE:/tmp/krb5cc_${WORKSHOP_USER}"
kinit "${WORKSHOP_USER}"
```

## `kinit: Client not found in Kerberos database`

Wrong user name or realm. Check `echo "${WORKSHOP_USER}"` and use the principal your instructor gave you (`user@REALM`).

## `kinit: Preauthentication failed` / `Password incorrect`

Wrong password. Retry once. Repeated failures can lock your account — then ask your instructor.

## `kinit -R` fails ("KDC can't fulfill requested option")

Your ticket is not renewable, or its `renew until` time has passed. Run `kinit "${WORKSHOP_USER}"` again; to see whether renewable tickets are allowed, use `kinit -l 3m -r 1h` and check `renew until` in `klist`. If it is missing, your cluster does not allow renewal; skip the renewal step.

## `Ticket expired` or `GSS initiate failed` in the middle of a lab

Your ticket ran out. Run `kinit "${WORKSHOP_USER}"` and repeat the failed command.

## `kinit: Clock skew too great`

The time on your machine differs from the server by more than 5 minutes. Ask your instructor.

## `kinit: Cannot contact any KDC` / `Cannot find KDC for realm`

Network or client configuration issue on the machine you use. Ask your instructor.

## `kdestroy: No credentials cache found`

You have no ticket — this is expected right after `kdestroy` and is not a problem.

## Section 7: `kinit -kt` fails

- `Keytab contains no suitable keys` / `Client not found`: the principal you typed is not the one listed by `klist -kt "${KEYTAB}"` — copy it exactly.
- `Preauthentication failed`: the keytab is outdated (password changed or keytab re-created). Ask your instructor for a new one.
- `Permission denied` on the keytab: check `ls -l "${KEYTAB}"`.

## `check.sh` fails on `KRB5CCNAME` or custom cache

Run `kdestroy`, then `unset KRB5CCNAME`, `rm -f "/tmp/krb5cc_${WORKSHOP_USER}_lab"`, and `kinit "${WORKSHOP_USER}"`. Then run the check again.
