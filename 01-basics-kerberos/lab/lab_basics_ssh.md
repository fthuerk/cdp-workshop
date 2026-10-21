# SSH key hands-on lab (short)

Goal: log in to the edge node with an SSH key instead of typing your password every time.

You create a **key pair**: a private key (stays on your machine, never share it) and a public key (goes onto the edge node). Pick **Part A** (key created on the edge node) or **Part B** (key created on your Windows laptop with PuTTY).

```bash
export EDGE_NODE=<edge_node_hostname>
export WORKSHOP_USER=<your_username>
```

---

## Part A — Key created on the edge node, used from macOS/Linux/Windows OpenSSH

### 1. Create the key (on the edge node)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_workshop -C "${WORKSHOP_USER}@workshop"
# Enter a passphrase when prompted (recommended)
```

This creates `~/.ssh/id_workshop` (private) and `~/.ssh/id_workshop.pub` (public).

### 2. Authorize the public key

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat ~/.ssh/id_workshop.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3. Copy the private key to your laptop

Run **on your laptop**:

```bash
scp "${WORKSHOP_USER}@${EDGE_NODE}:~/.ssh/id_workshop" ~/.ssh/id_workshop
chmod 600 ~/.ssh/id_workshop
```

Then delete the private key from the edge node (it only needs to live on your laptop):

```bash
rm ~/.ssh/id_workshop
```

> Alternative: create the key on your laptop with the `ssh-keygen` command above and run `ssh-copy-id -i ~/.ssh/id_workshop.pub "${WORKSHOP_USER}@${EDGE_NODE}"`. Then the private key never travels.

### 4. Add it to `~/.ssh/config` (on your laptop)

```
Host workshop
    HostName <edge_node_hostname>
    User <your_username>
    IdentityFile ~/.ssh/id_workshop
    IdentitiesOnly yes
```

### 5. Test

```bash
ssh workshop
```

You should be logged in without a password prompt (only the key passphrase, if you set one).

---

## Part B — Key created with PuTTY (Windows)

### 1. Create the key

1. Start **PuTTYgen**.
2. Select type **EdDSA (Ed25519)** (or RSA, 4096 bits), click **Generate**, move the mouse.
3. Enter a **key passphrase** (recommended).
4. Click **Save private key** → e.g. `C:\Users\<you>\.ssh\workshop.ppk`.
5. Copy the text from the box **Public key for pasting into OpenSSH authorized_keys file**.

### 2. Authorize the public key (on the edge node)

Log in once with your password, then:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "<paste the public key line here>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3. Include the key in the PuTTY session

1. Open **PuTTY** and enter the edge node under **Session → Host Name**.
2. Go to **Connection → Data** and set **Auto-login username** to your username.
3. Go to **Connection → SSH → Auth → Credentials** and, under **Private key file for authentication**, browse to `workshop.ppk`.
4. Go back to **Session**, type a name (e.g. `workshop`) under **Saved Sessions**, click **Save**.
5. Click **Open**. Enter the key passphrase if you set one.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Still asked for the account password | Wrong permissions: `~/.ssh` must be `700`, `authorized_keys` `600`, and your home directory not group/world-writable |
| `Permission denied (publickey)` | Public key not in `authorized_keys`, or wrong `IdentityFile` / `.ppk` |
| `UNPROTECTED PRIVATE KEY FILE` | Run `chmod 600 ~/.ssh/id_workshop` on your laptop |
| Debug details | `ssh -v workshop` |
