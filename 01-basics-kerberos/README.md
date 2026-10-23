# Module 01 — Basics: Kerberos

How you prove your identity to the grid monitoring platform: get a ticket, read it, renew it, and recognise the errors that every other lab shows when the ticket is missing or expired.

**Estimated time:** ~35 minutes (core ~30 min; keytab section 7 and stretch are optional)

## Prerequisites

- Module [00-setup](../00-setup/README.md) complete (workshop data on HDFS)
- Your Kerberos user name and password from your instructor

## Learning goals

After this module you can:

- Explain what a Kerberos ticket is and why the cluster asks for it
- Get a ticket with `kinit`, inspect it with `klist`, and remove it with `kdestroy`
- Read the principal, expiry, and renewal times of your ticket
- Renew a ticket with `kinit -R` and tell when you must log in again
- Store a ticket in a custom cache and make tools find it with `KRB5CCNAME`
- Match common error messages to their cause (no ticket, expired, wrong user, wrong password)
- Describe when a keytab is used instead of a password

## Flow

| Phase | Content |
|-------|---------|
| Concept (trainer) | Ticket as proof of identity; principal and realm; TGT vs service ticket; authentication vs authorization |
| Core lab | [lab_basics_kerberos.md](lab/lab_basics_kerberos.md) sections 1–6 |
| Optional | Section 7 (keytab, only if your instructor provides one) and stretch tasks |
| Self-check | `./01-basics-kerberos/lab/check.sh` |

## Trainer materials

- [trainer/notes.md](trainer/notes.md) — timing, check-question talking points, pitfalls
- [trainer/demos.md](trainer/demos.md) — keytab demo, cache types, Beeline and browser (trainer-only)

## Next module

[02-basics-hdfs](../02-basics-hdfs/README.md)

---
*The generation of these labs was supported by AI.*
