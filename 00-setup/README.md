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

## What the trainer prepares (summary)

- HDFS workshop root with sample datasets under `${WORKSHOP_ROOT}/data/`
- Optional home directories `/user/<participant>`
- Module **02** adds HDFS lab paths (secret, quota, big file)

Details: [admin/README.md](admin/README.md)

## Next module

[01-basics-kerberos](../01-basics-kerberos/README.md)
