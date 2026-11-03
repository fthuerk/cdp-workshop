# Atlas lab — troubleshooting

## Entity not found after creating a table

- Wait up to **one minute** and search again. The Hive Atlas hook is asynchronous.  
- Confirm the table exists in Hue: `SHOW TABLES;` in database `${ws_user}`.  
- Ask your instructor whether the **Hive Atlas hook** and Kafka bridge are healthy.

## Lineage empty or missing CTAS children

- Finish **section 3** in Hue and wait briefly, then refresh the **Lineage** tab.  
- Open lineage on **`atlas_meter_src`**; it is the root, so its children appear downstream only.  
- If still empty, instructor checks Atlas hook configuration and Hive execution engine logging.

## Ranger: `does not have privilege` on `CREATE` or `INSERT`

The lab only uses managed tables in your own database (default locations, no `LOCATION` clause). Same Hive policies on your personal database as in the Hive module are enough. Ask your instructor.

## Cannot create classification or glossary

- Some clusters restrict **Atlas admin** actions. Use trainer-precreated classification **`<your_username>_PII`** or glossary **Metering** / term **Active Power**, and only **assign** tags or terms to your entities.  
- See [trainer/notes.md](../trainer/notes.md).

## Tag not visible on child table

- **Propagation** may be disabled or delayed. Verify the tag on **`atlas_meter_src`** first.  
- **`atlas_meter_anonymized`** drops `device_id`; column-level **PII** tags may behave differently from table-level tags — table-level tag on the source is the main demo.

## Self-check: table missing

- Re-run lab sections 1 and 3 in Hue.  
- Set `HS2_URL` if `check.sh` cannot reach HiveServer2 (the same JDBC URL you use for Beeline).  
## Hue / Knox session expired

Renew Kerberos (`kinit`) and reload Hue. Atlas uses the same SSO path when opened via Knox.
