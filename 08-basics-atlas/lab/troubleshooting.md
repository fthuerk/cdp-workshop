# Atlas lab — troubleshooting

## Entity not found after creating a table

- Wait up to **one minute** and search again. The Hive Atlas hook is asynchronous.  
- Confirm the table exists in Hue: `SHOW TABLES;` in database `${ws_user}`.  
- Ask your instructor whether the **Hive Atlas hook** and Kafka bridge are healthy.

## Lineage empty or missing CTAS children

- Finish **section 3** in Hue and wait briefly, then refresh the **Lineage** tab.  
- Open lineage on **`atlas_meter_src`**, not only on the external staging table **`atlas_meter_ext`**.  
- If still empty, instructor checks Atlas hook configuration and Hive execution engine logging.

## `Permission denied` on external table or `LOCATION`

- The path must be `${WORKSHOP_ROOT}/08-atlas/data` (for example `/2026_cdp_workshop/08-atlas/data`).  
- Instructor re-runs `./08-basics-atlas/setup/setup.sh` and confirms Ranger HDFS read for workshop users.

## Cannot create classification or glossary

- Some clusters restrict **Atlas admin** actions. Use trainer-precreated classification **`<your_username>_PII`** or glossary **Metering** / term **Active Power**, and only **assign** tags or terms to your entities.  
- See [trainer/notes.md](../trainer/notes.md).

## Tag not visible on child table

- **Propagation** may be disabled or delayed. Verify the tag on **`atlas_meter_src`** first.  
- **`atlas_meter_anonymized`** drops `device_id`; column-level **PII** tags may behave differently from table-level tags — table-level tag on the source is the main demo.

## Self-check: table missing

- Re-run lab sections 1 and 3 in Hue.  
- Set `HS2_URL` if `check.sh` cannot reach HiveServer2 (same JDBC URL as on your handout).  
- Shared CSV missing: instructor runs `./08-basics-atlas/setup/setup.sh`.

## Hue / Knox session expired

Renew Kerberos (`kinit`) and reload Hue. Atlas uses the same SSO path when opened via Knox.
