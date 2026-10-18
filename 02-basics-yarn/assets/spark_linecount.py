#!/usr/bin/env python3
"""Workshop 02: count lines in a text file on HDFS and write a single-part result path."""
import sys

from pyspark.sql import SparkSession


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: spark_linecount.py <input_hdfs_path> <output_hdfs_path>", file=sys.stderr)
        sys.exit(2)
    input_path, output_path = sys.argv[1], sys.argv[2]
    spark = (
        SparkSession.builder.appName("workshop-02-yarn-linecount")
        .getOrCreate()
    )
    line_count = spark.read.text(input_path).count()
    spark.sparkContext.parallelize([f"line_count={line_count}"]).saveAsTextFile(output_path)
    spark.stop()


if __name__ == "__main__":
    main()
