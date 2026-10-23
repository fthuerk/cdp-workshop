# Sample data (synthetic)

CSV files here support the grid monitoring pilot use case:

- **Smart-meter / field trial** — `sample-landisgyr-data.csv`
- **Operator weather stations** — `sample-operator-weather.csv`
- **Market / energy** — `sample-awattar-prices.csv`, `sample-energy-charts.csv`
- **Public weather** — `sample-open-meteo.csv`, `sample-geosphere-austria.csv`
- **Context / reference** — basemap, OpenStreetMap, Statistik Austria, holidays

Values are synthetic and safe to store in git. Production datasets with restricted data must not be committed; load approved data only on the cluster under `${WORKSHOP_ROOT}/data/` via bootstrap.

Bootstrap uploads each file into its own HDFS folder, for example:

`/2026_cdp_workshop/data/landisgyr/sample-landisgyr-data.csv`

Hive modules can point `LOCATION` at the folder level.

---
*The generation of these labs was supported by AI.*
