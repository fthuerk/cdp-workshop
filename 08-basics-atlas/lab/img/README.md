# Screenshots for the Atlas lab

The lab already links every image and has a **Screenshot fallback** text under each one. To add a screenshot, save a PNG here with exactly the file name below. No lab text needs to change; the image appears as soon as the file exists.

| File | Lab section | What to capture |
|------|-------------|-----------------|
| `atlas-01-search-result.png` | 2 | Search for `atlas_meter_src`, result list with the `hive_table` hit |
| `atlas-02-table-detail.png` | 2 | Table page: Properties and Schema |
| `atlas-03-lineage-downstream.png` | 4 | Lineage of `atlas_meter_src` with both CTAS children |
| `atlas-04-lineage-process.png` | 4 | Process node selected, CTAS query text visible |
| `atlas-05-tag-attach.png` | 5 | Add classification dialog |
| `atlas-06-tag-child.png` | 5 | Propagated tag on `atlas_meter_daily` |
| `atlas-07-glossary-term.png` | 6 | Glossary `Metering`, term `Active Power` |
| `atlas-08-glossary-assignment.png` | 6 | Term assigned to `active_power_kw` or the table |

Tips: crop to the relevant area, around 1200 px wide, and use a demo user (not a real person's name) so no identifiers appear. Check which are still missing with `./check-screenshots.sh`.
