# Optional demos — Module I2 Ranger

Not part of the 30-minute lab. Use when time allows or for a second session.

## Tag-based policy (Atlas + Ranger)

If the cohort completed [I1-basics-atlas](../../I1-basics-atlas/README.md):

1. In Atlas, ensure classification **`<username>_PII`** exists on column **`device_id`** (or table-level on a demo table).
2. In Ranger → Hive → **Tag Policies** (or **Tag** tab), create a tag policy on that classification:
   - Mask or deny `select` on tagged columns for group **`workshop`**
3. Contrast **resource-based** policies (this lab) with **tag-based** policies (metadata-driven, survives table renames if tags propagate).

## Policy ordering and priority

Create two allow policies on the same table with different mask types and show **policy priority** (lower number = higher priority). Useful for “exception” groups (managers vs analysts).

## Impala Ranger service

Run the same `SELECT` in **Impala** editor after Hive policies exist — show that **Impala** requires policies on the **Impala** service (or unified model if your CDP version merges them). Do not assume Hive policies alone cover Impala.

## Export policy JSON (REST)

For admins familiar with [00-setup/admin/ranger](../../00-setup/admin/ranger/README.md):

```bash
# Example: list policies (adjust URL, service, credentials)
curl -s -u "${RANGER_USER}:${RANGER_PASSWORD}" \
  "${RANGER_URL}/service/public/v2/api/service/cm_hive/policy" | python3 -m json.tool | head
```

Discuss Git-managed policies vs UI edits — not required for the basics lab.

## Ranger + Atlas audit correlation

Open Atlas entity for `ranger_lab.meter_readings` and Ranger audit for the same query time — metadata vs authorization vs audit trail for compliance conversations.

## Data masking types catalog

Quick tour of other mask types not used in the lab: **Redact**, **Date mask**, **Custom** expression. Link to Cloudera docs for your version.
