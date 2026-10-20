# Kerberos hands-on lab

Run sections in order. Adjust `WORKSHOP_ROOT` if your cluster uses a different workshop path.

Kerberos is how the cluster knows who you are. You prove your identity once with a password, receive a **ticket**, and the cluster services accept that ticket instead of asking for the password again. Kerberos answers *who are you?* — whether you may read a path or a table is decided separately by HDFS permissions and Ranger.

This lab starts **without** a ticket on purpose, so you see what a missing ticket looks like before you fix it.

```bash
# Your identity (short name, same account as on the edge node)
export WORKSHOP_USER=<your_username>

# Workshop path on HDFS (adjust WORKSHOP_ROOT if needed)
export WORKSHOP_ROOT=/2026_cdp_workshop
```

Your full identity is called a **principal**: `<user>@<REALM>`. The realm is the name of the Kerberos domain of your cluster; `kinit` fills it in for you.

---

## 1. No ticket, no access

**Goal:** See what the cluster says when you have no ticket.

Remove any existing ticket, then ask for the list of tickets you hold:

```bash
# Start clean (may report that there is no cache — that is fine)
kdestroy

# List your tickets
klist
```

`klist` should tell you that no credentials cache was found or that it is empty. Now try to use the cluster:

```bash
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
```

You should get an error that mentions `GSSException`, `Failed to find any Kerberos tgt`, or `No valid credentials provided`. Remember this message: it means *you have no (valid) ticket*.

---

## 2. Get and read a ticket

**Goal:** Get a ticket with `kinit` and read what `klist` tells you.

`kinit` asks for your password and requests a **ticket-granting ticket (TGT)** from the Kerberos server (KDC):

```bash
# Enter your password when prompted
kinit "${WORKSHOP_USER}"

# Show your ticket
klist
```

`klist` output, top to bottom:

- **Ticket cache** — where your ticket is stored (a file, or a keyring on some systems)
- **Default principal** — who you are
- **Valid starting / Expires** — the time window in which the ticket works
- **`krbtgt/<REALM>@<REALM>`** — the TGT itself. It is your proof of identity that is used to obtain tickets for individual services
- **renew until** (if shown) — the latest time up to which you can extend the ticket

Run the same HDFS command again:

```bash
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
```

It now works without a password prompt. Behind the scenes the Hadoop client used your TGT to get a short-lived ticket for the HDFS service. Java tools keep such service tickets in memory, so `klist` usually does not list them.

**Check question:** When does your ticket expire? What would happen to a job that runs longer than that?

---

## 3. Destroy a ticket

**Goal:** Remove your ticket and see access disappear immediately.

Destroying your ticket is good hygiene at the end of a session, and especially on shared machines:

```bash
# Remove the ticket
kdestroy

# Confirm it is gone
klist
```

Try HDFS once more:

```bash
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
```

You should see the same error as in section 1. Get your ticket back for the next sections:

```bash
kinit "${WORKSHOP_USER}"
```

**Check question:** If someone copies your ticket file while it is valid, what can they do? What can they *not* do?

---

## 4. Lifetime and renewal

**Goal:** Request a ticket with a chosen lifetime and extend it without typing your password.

Request a ticket that is valid for 3 minutes and renewable for up to 1 hour, then look at the times:

```bash
# -l = lifetime, -r = renewable lifetime
kinit -l 3m -r 1h "${WORKSHOP_USER}"

klist
```

Compare **Expires** and **renew until**. The cluster sets upper limits; you can ask for less, never for more. If `renew until` is missing, your cluster does not allow renewable tickets — continue with the next step anyway and note the `kinit -R` error.

Wait a minute, then renew the ticket and compare the **Expires** time before and after:

```bash
# Extend the ticket (no password needed)
kinit -R

klist
```

`kinit -R` renews the *same* ticket until its `renew until` limit. After that limit you must run `kinit` with your password again.

Get a normal ticket back:

```bash
kinit "${WORKSHOP_USER}"
```

---

## 5. Custom ticket cache

**Goal:** Store a ticket in a file of your choice and make your tools find it.

Your ticket is stored in a **cache**. By default every tool looks in the same default location. You can choose another one, for example to hold a second identity next to your own:

```bash
# Start clean, then create a ticket in a file of your own
kdestroy
kinit -c "/tmp/krb5cc_${WORKSHOP_USER}_lab" "${WORKSHOP_USER}"

# The default cache is still empty ...
klist
```

```bash
# ... but your file contains the ticket
klist -c "/tmp/krb5cc_${WORKSHOP_USER}_lab"
```

Now run HDFS. It looks in the default cache and has no idea about your file:

```bash
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
```

You should get the "no valid credentials" error again, although you hold a valid ticket. Tell your tools where to look with the environment variable `KRB5CCNAME`:

```bash
export KRB5CCNAME="FILE:/tmp/krb5cc_${WORKSHOP_USER}_lab"

klist
hdfs dfs -ls "${WORKSHOP_ROOT}/data"
```

Now both work. *"I have a ticket but my tool does not see it"* is one of the most common Kerberos problems — check `klist` and `echo "${KRB5CCNAME}"` first.

Clean up: destroy the custom cache, stop pointing at it, and get a normal ticket:

```bash
kdestroy
unset KRB5CCNAME
kinit "${WORKSHOP_USER}"
```

---

## 6. Common errors

**Goal:** Trigger the typical Kerberos errors on purpose and recognise their cause.

You have already met *no ticket* (sections 1 and 3). Ask for a ticket for a user that does not exist:

```bash
kinit "${WORKSHOP_USER}_does_not_exist"
```

You should get **Client not found in Kerberos database** — the principal is misspelled or unknown. Next, run `kinit` and type a **wrong password** on purpose:

```bash
kinit "${WORKSHOP_USER}"
```

You should get **Preauthentication failed** or **Password incorrect** — wrong password. Be careful with repeated failures: many sites lock an account after a few attempts.

Run `kinit` with the correct password, then look at what the client does internally. `KRB5_TRACE` prints every step:

```bash
kinit "${WORKSHOP_USER}"

# Print each step of the login to the screen
KRB5_TRACE=/dev/stdout kinit "${WORKSHOP_USER}"
```

In the trace, look for the Kerberos server (KDC) that is contacted and the step where your password is used. Use this when `kinit` hangs or fails without a clear message.

| Message | Usually means | What you do |
|---------|---------------|-------------|
| `Failed to find any Kerberos tgt` / `No valid credentials` | No ticket, expired ticket, or tool looks in the wrong cache | `klist`, then `kinit`; check `KRB5CCNAME` |
| `Ticket expired` | Ticket lifetime is over | `kinit` again |
| `Client not found in Kerberos database` | Wrong user name or realm | Check spelling of `WORKSHOP_USER` |
| `Preauthentication failed` / `Password incorrect` | Wrong password | Retry carefully; ask your instructor to reset it |
| `Clock skew too great` | Clock of your machine is off by more than 5 minutes | Ask your instructor |
| `Cannot contact any KDC` / `Cannot find KDC for realm` | Network or client configuration problem | Ask your instructor |

---

## 7. Optional — keytab instead of password

**Goal:** Log in without typing a password, the way scheduled jobs do.

Skip this section if your instructor did not give you a keytab. Nothing else in the lab or in the self-check depends on it.

A **keytab** is a file that holds the key of a principal — in effect a password stored in a file. Scripts and scheduled jobs use it because nobody is there to type a password. Anyone who can read the file *is* that principal, so it must be readable only by its owner.

Set the path your instructor gave you and look at its permissions and content:

```bash
export KEYTAB="<path-to-keytab-from-your-instructor>"

# Permissions: only the owner should be able to read it
ls -l "${KEYTAB}"

# Principals stored in the keytab
klist -kt "${KEYTAB}"
```

If the file is readable by others, fix it with `chmod 600 "${KEYTAB}"` (only if you own the file). Log in with the principal listed by `klist -kt`:

```bash
kdestroy
kinit -kt "${KEYTAB}" "<principal-from-klist-kt>"

klist
```

You hold a ticket without having typed a password. The ticket behaves exactly like a password-based one — same lifetime, same expiry.

Rules of thumb: password for interactive work, keytab for automation; never copy a keytab into Git, mail, or chat; if the account's password is changed or the keytab is re-created, old copies stop working.

Return to your own identity:

```bash
kdestroy
kinit "${WORKSHOP_USER}"
```

---

## Stretch (optional)

- **Watch a ticket expire.** Run `kinit -l 2m "${WORKSHOP_USER}"`, wait until it expires, and run an HDFS command. Which message do you get? Compare it to section 1.
- **Encryption types.** Run `klist -e` and look at the encryption type of your TGT. When can a mismatch between client and server cause errors?
- **Other tools.** Run `kinit` first in your other labs. Which error do you get in Beeline when your ticket is missing?

---

## Self-check

```bash
./01-basics-kerberos/lab/check.sh
```

The script expects a valid ticket for `WORKSHOP_USER` in the default cache. If it fails, see [troubleshooting.md](troubleshooting.md).
