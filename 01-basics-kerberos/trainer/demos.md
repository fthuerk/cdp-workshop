# Trainer live demos — Kerberos

Optional extras while participants run the lab. Use `${WORKSHOP_ROOT}` from your cluster handout.

---

## 1. Keytab login (if no keytab for participants)

**Goal:** Show a keytab login on the projector when participants cannot do lab section 7 themselves.

Use a service or demo principal whose keytab you may show. Never display a real production keytab path in the room.

```bash
klist -kt "<path-to-keytab>"
kdestroy
kinit -kt "<path-to-keytab>" "<principal>"
klist
```

Show `ls -l` on the file (mode 600) and explain what happens if the password of the principal is changed.

**Talking point:** A keytab is a password in a file — it belongs to jobs, not to people.

---

## 2. Ticket cache types

**Goal:** Explain why a valid ticket is sometimes invisible to Java.

Run `klist` and read the first line. Show the cache types:

- `FILE:/tmp/krb5cc_<uid>` — readable by every tool
- `KEYRING:persistent:<uid>` and `KCM:<uid>` — managed by the OS; native tools see them, older Java clients may not

**Talking point:** If `kinit` works but `hdfs` does not, check the cache type first.

---

## 3. Kerberos in Beeline

**Goal:** Show that the JDBC URL carries the service principal.

Look at the Beeline URL from the Hive lab. The `principal=hive/_HOST@<REALM>` part names the service you want to talk to. Run it once with a ticket, then after `kdestroy`.

**Talking point:** `_HOST` is replaced by the server name you connect to — hostnames and DNS matter for Kerberos.

---

## 4. Browser access (SPNEGO)

**Goal:** Show Kerberos in a web UI.

Open a service UI (for example the ResourceManager) directly, not via Knox, with a ticket on your laptop and the browser configured for negotiate authentication. Compare with no ticket: you get a `401`.

Only if your environment supports it; skip when users log in through Knox with user name and password.

**Talking point:** Same ticket, different client.
