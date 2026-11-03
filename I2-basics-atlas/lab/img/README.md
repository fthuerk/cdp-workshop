# Screenshots for the Atlas lab

The lab already links every image and has a **Screenshot fallback** text under each one. To add a screenshot, save a PNG here with exactly the file name below. No lab text needs to change; the image appears as soon as the file exists.

| File | Lab section | What to capture |
|------|-------------|-----------------|
| `atlas-01-search-result.png` | 2 | Search for `atlas_meter_src`, result list with the `hive_table` hit |
| `atlas-02-table-detail.png` | 2 | Table page: Properties and Schema |
| `atlas-03-lineage-downstream.png` | 4 | Lineage of `atlas_meter_src` with both CTAS children |
| `atlas-04-lineage-process.png` | 4 | Process node selected, CTAS query text visible |
| `5_pii_columns.png` | 5 | `cdp_workshop.meter_readings` Schema with `PII` on `customer_name` and `customer_email` |
| `6_pii_propagation.png` | 6 | `atlas_customer_copy` Schema with propagated `PII` |
| `6_tag_based_policy_redacted.png` | 6 | Hue result with redacted columns |
| `7_active_power_kw_term_assignment.png` | 7 | Column with term `Active Power` assigned |
| `7_active_power_glossary_term_category.png` | 7 | Term `Active Power` with category and assigned column |

Tips: crop to the relevant area, around 1200 px wide, and use a demo user (not a real person's name) so no identifiers appear. Check which are still missing with `./check-screenshots.sh`.

---
*The generation of these labs was supported by AI.*
