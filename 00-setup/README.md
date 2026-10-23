# Module 00 — Setup

Prepare your account and confirm cluster access before any hands-on module.

**Estimated time:** 15 minutes

## Participant checklist

1. SSH to the workshop edge node (URL from your trainer).
2. Obtain a Kerberos ticket:
   ```bash
   kinit <your_user>
   klist
   ```
3. Clone or use the shared repo path (trainer will set `WORKSHOP_LOCAL`, often `/opt/cdp-workshop`).
4. Copy configuration (trainer may do this globally):
   ```bash
   cp config.env.example config.env
   # edit WORKSHOP_ROOT, HS2_URL, Knox/Hue URLs if needed
   ```
5. Run the environment check:
   ```bash
   ./00-setup/participant/check_env.sh
   ```
6. Open **Hue** and **Knox** links from the runbook; confirm you can sign in.

## Path B: no trainer access to the platform (self-service)

If nobody can run the admin bootstrap, set up the workshop in your own HDFS home instead:

```bash
kinit <your_user>
git clone <repo-url> cdp-workshop && cd cdp-workshop
./00-setup/participant/setup.sh                 # default: /user/<you>/cdp_workshop
# or: ./00-setup/participant/setup.sh --root /user/<you>/my_ws --modules "02 04"
```

The script writes `config.env`, uploads `data/samples` and runs the module setup scripts with your own
ticket. At the end it prints the line to use in every lab instead of the default path:

```bash
export WORKSHOP_ROOT=/user/<you>/cdp_workshop
```

Remove everything again with `./00-setup/participant/setup.sh --remove`.

Every script and `check.sh` takes the location from the environment first, then `config.env`. Run a single module
setup with `./02-basics-hdfs/setup/setup.sh --skip-kinit --root /user/<you>/cdp_workshop`. In the labs, the header block
keeps your exported `WORKSHOP_ROOT`; set `WORKSHOP_HOME` there too if you want lab output outside `/user/<you>`.

**What differs in self-service mode**

| Module | Difference |
|--------|------------|
| 02 HDFS | No space quota (the quota upload does not fail). You own `secret`, so `cat` works: use another user's path or skip. |
| 04, 05, 07, 10 | Use the shared Hive warehouse (`ws_<you>` database); your account needs the usual Hive/HDFS rights there. |
| 06 Spark | Output goes to `WORKSHOP_HOME`; the table step needs the same Hive rights. |
| 08 Atlas | Needs the Atlas Hive hook on the cluster; no setup script. |

## What the trainer prepares (Path A) (summary)

- HDFS workshop root with sample datasets under `${WORKSHOP_ROOT}/data/`
- Optional home directories `/user/<participant>`
- Module **02** adds HDFS lab paths (secret, quota, big file)

Details: [admin/README.md](admin/README.md)

## Next module

[01-basics-kerberos](../01-basics-kerberos/README.md)

---
*The generation of these labs was supported by AI.*
