#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
load_config

require_cmd hdfs spark-submit
require_kerberos_ticket

fail=0
pass() { echo "[PASS] $*"; }
fail_msg() { echo "[FAIL] $*"; fail=1; }

WS_USER="${WORKSHOP_USER:-${USER}}"
USER_HOME="${WORKSHOP_HOME}"
SPARK_LAB="${WORKSHOP_ROOT}/06-spark"
BATCH_OUT="${USER_HOME}/spark-batch-curated"
INTERACTIVE_OUT="${USER_HOME}/spark-curated"
EXPECTED_JOINED=24
EXPECTED_METER_OK=12

expect_path() {
  if hdfs dfs -test -e "$1" 2>/dev/null; then pass "$2"; else fail_msg "$2 — $3"; fi
}

expect_path "${SPARK_LAB}/assets/spark_cleanse_join.py" \
  "Shared Spark script on HDFS" \
  "ask instructor to run 06-basics-spark/setup/setup.sh"

expect_path "${BATCH_OUT}/_SUCCESS" \
  "Batch Parquet output (_SUCCESS)" \
  "redo lab section 6"

expect_path "${INTERACTIVE_OUT}/_SUCCESS" \
  "Interactive Parquet output (_SUCCESS)" \
  "redo lab section 5"

count_py="$(mktemp)"
trap 'rm -f "${count_py}"' EXIT
cat > "${count_py}" <<'PY'
import sys
from pyspark.sql import SparkSession

path = sys.argv[1]
spark = SparkSession.builder.appName("workshop-06-check").master("local[2]").getOrCreate()
print(spark.read.parquet(path).count())
spark.stop()
PY

count_parquet() {
  spark-submit --master 'local[2]' "${count_py}" "$1" 2>/dev/null | tail -1 || true
}

batch_count="$(count_parquet "${BATCH_OUT}")"
if [[ "${batch_count}" == "${EXPECTED_JOINED}" ]]; then
  pass "Batch joined row count is ${EXPECTED_JOINED}"
else
  fail_msg "Batch row count is '${batch_count:-unknown}', expected ${EXPECTED_JOINED} — redo lab sections 4 and 6"
fi

meter_csv="${WORKSHOP_ROOT}/data/landisgyr/sample-landisgyr-data.csv"
meter_ok_py="$(mktemp)"
cat > "${meter_ok_py}" <<'PY'
import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

path = sys.argv[1]
spark = SparkSession.builder.appName("workshop-06-check-meter").master("local[2]").getOrCreate()
meter = (
    spark.read.option("header", True)
    .schema(
        "ts_utc STRING, station_id STRING, device_id STRING, phase STRING, "
        "active_power_kw DOUBLE, reactive_power_kvar DOUBLE, voltage_v DOUBLE, "
        "current_a DOUBLE, power_factor DOUBLE, frequency_hz DOUBLE, "
        "transformer_load_pct DOUBLE, quality_flag STRING, event_code STRING, "
        "comm_status STRING"
    )
    .csv(path)
    .filter(F.col("quality_flag") == "OK")
    .dropDuplicates(["ts_utc", "station_id", "device_id", "phase"])
)
print(meter.count())
spark.stop()
PY

ok_count="$(spark-submit --master 'local[2]' "${meter_ok_py}" "${meter_csv}" 2>/dev/null | tail -1 || true)"
if [[ "${ok_count}" == "${EXPECTED_METER_OK}" ]]; then
  pass "Cleansed meter row count is ${EXPECTED_METER_OK}"
else
  fail_msg "Cleansed meter count is '${ok_count:-unknown}', expected ${EXPECTED_METER_OK} — redo lab section 2"
fi
rm -f "${meter_ok_py}"

if [[ ${fail} -ne 0 ]]; then
  echo "Self-check failed. See lab/troubleshooting.md"
  exit 1
fi
echo "Spark lab self-check passed."
