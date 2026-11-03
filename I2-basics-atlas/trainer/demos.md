# Trainer live demos — Atlas (optional)

These topics are **not** in the 20-minute participant lab. Use them in Q&A or a longer governance block.

## Advanced search

Show **Advanced Search** with filters such as `typeName:hive_table` and `dbName:<demo_user>`. Mention DSL queries if your Atlas version exposes them in the UI.

## Shared tables in `cdp_workshop`

The trainer-owned database `cdp_workshop` (created by I1-basics-ranger `setup.hql`) is a clean, stable Atlas demo: search `hive_table` with `dbName:cdp_workshop`, show `meter_readings`, `customer_master`, `station_assignment`, and attach `PII` to `meter_readings.customer_email` / `customer_name`. Unlike participant tables, these are not dropped during the lab cleanup. Run the I1 setup first if the database does not exist yet.

## Audits tab

On a table entity, open **Audits** and point at create/update events. Tie to operational questions (“who registered this table?”).

## Atlas REST API

From an edge node with a valid ticket and Knox URL:

```bash
curl -s -u "${WORKSHOP_USER}" \
  "${ATLAS_BASE}/api/atlas/v2/search/basic?query=atlas_meter_src" | head
```

Adjust `${ATLAS_BASE}` from your runbook. Do not paste passwords into participant docs.

## Deleted entities and lineage

After `DROP TABLE` in Hive, show the entity status **DELETED** in Atlas and that **lineage edges** often remain for audit.

## Ranger tag policies

Lab section 6 already shows a tag-based masking policy in action. For a longer governance block, open the policy `PII_mask` in Ranger (Tag Based Policies) and walk through its structure; optionally show a tag-based deny policy as the "no access at all" alternative.
