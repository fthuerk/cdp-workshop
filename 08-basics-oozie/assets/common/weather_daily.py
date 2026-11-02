#!/usr/bin/env python3
"""Workshop 08: per-station weather summary as Parquet (started by the Oozie spark3 action)."""
import sys

from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: weather_daily.py <weather_csv_hdfs> <output_parquet_hdfs>", file=sys.stderr)
        sys.exit(2)
    weather_path, output_path = sys.argv[1:3]

    spark = SparkSession.builder.appName("workshop-08-weather-daily").getOrCreate()

    weather = (
        spark.read.option("header", True)
        .schema(
            "ts_utc STRING, weather_station_id STRING, station_name STRING, "
            "temperature_c DOUBLE, relative_humidity_pct INT, wind_speed_mps DOUBLE, "
            "precipitation_mm DOUBLE, pressure_hpa DOUBLE, weather_quality STRING"
        )
        .csv(weather_path)
        .filter(F.col("weather_quality") == "OK")
    )

    summary = weather.groupBy("weather_station_id", "station_name").agg(
        F.count("*").alias("readings"),
        F.round(F.avg("temperature_c"), 1).alias("avg_temperature_c"),
        F.min("temperature_c").alias("min_temperature_c"),
        F.max("temperature_c").alias("max_temperature_c"),
        F.round(F.sum("precipitation_mm"), 1).alias("total_precipitation_mm"),
    )

    summary.coalesce(1).write.mode("overwrite").parquet(output_path)
    spark.stop()


if __name__ == "__main__":
    main()
