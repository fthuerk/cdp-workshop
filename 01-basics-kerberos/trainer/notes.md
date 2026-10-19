# Trainer notes — Module 01 Kerberos

No `setup/` scripts: the lab changes no shared cluster state. It only needs `00-setup` (data under `${WORKSHOP_ROOT}/data`) and a working `kinit` for each participant. Recommended learning order is before the HDFS lab, but the lab is independent.

## Suggested timing (~35 min)

| Minutes | Activity |
|---------|----------|
| 0–7 | Concept: wristband analogy; `kinit` → TGT → service tickets fetched automatically; principal `user@REALM`; Kerberos = who you are, Ranger/ACLs = what you may do |
| 7–12 | Sections 1–2 (no ticket, get ticket, read `klist`) |
| 12–17 | Section 3 (destroy) and section 4 (lifetime, renewal) |
| 17–22 | Section 5 (custom cache, `KRB5CCNAME`) |
| 22–30 | Section 6 (common errors, `KRB5_TRACE`) |
| 30–35 | Optional keytab (section 7) or [demos.md](demos.md) section 1; `check.sh` |

## Check question answers

- **Section 2 — expiry:** Typically 10–24 h, set by the KDC/cluster policy. A job needing the ticket longer than that fails with `GSS initiate failed` unless it uses a keytab or delegation tokens are renewed (details in advanced modules).
- **Section 3 — copied ticket:** Whoever has the ticket file can act as the user on any service until it expires, without knowing the password. They cannot request new tickets after expiry or change the password.

## Pitfalls

| Issue | Mitigation |
|-------|------------|
| Default cache is `KCM:` or `KEYRING:` (common on RHEL 8/9) and Java tools do not see the ticket | Troubleshooting first entry: export `KRB5CCNAME=FILE:...` for the whole session. Check `klist` first line before the session |
| Renewable tickets disabled or capped by policy (e.g. AD) | Lab section 4 says what to do; use it as a talking point on KDC policy |
| Participants lock their account with repeated wrong passwords in section 6 | Tell them to type a wrong password **once** |
| `kinit -l 2m` limits in the stretch task | Check that the KDC allows short lifetimes in your environment |
| Confusion: `klist` shows no service ticket after `hdfs` | Java keeps service tickets in memory; not an error |

## Talking points

- **Authentication vs authorization:** a valid ticket does not grant access — a `Permission denied` after a successful `kinit` is a Ranger/POSIX topic, not Kerberos.
- **Error table (section 6):** point out that the same messages appear in HDFS, YARN, Hive and Impala labs; first reaction is always `klist`.
- **Keytab (section 7):** without a keytab, discuss it as a concept slide only: used for scheduled jobs and services, same security as a password, regenerate invalidates old copies.

## After module

In the following labs, `kinit` is the first step. When something fails with `GSS` or `credentials`, start with `klist`.
