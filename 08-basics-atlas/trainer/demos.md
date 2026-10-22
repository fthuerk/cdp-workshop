# Trainer live demos — Atlas (optional)

These topics are **not** in the 20-minute participant lab. Use them in Q&A or a longer governance block.

## Advanced search

Show **Advanced Search** with filters such as `typeName:hive_table` and `dbName:<demo_user>`. Mention DSL queries if your Atlas version exposes them in the UI.

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

Show (read-only) a Ranger policy that references an Atlas classification — connects section 5 to enforcement without changing policies in the workshop.
