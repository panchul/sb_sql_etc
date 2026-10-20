from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def main() -> None:
    spark = SparkSession.builder \
        .appName("SparkSQLSandbox") \
        .master("local[*]") \
        .getOrCreate()

    data = [
        ("Alice", 34, "New York"),
        ("Bob", 29, "Boston"),
        ("Charlie", 41, "Seattle"),
        ("Diana", 28, "Boston"),
        ("Ethan", 36, "New York"),
        ("Fiona", 25, "Austin"),
    ]

    df = spark.createDataFrame(data, ["name", "age", "city"])
    df.createOrReplaceTempView("people")

    print("\nRaw data:")
    df.show()

    print("\nSQL query: cities with average age and count")
    spark.sql(
        """
        SELECT city,
               COUNT(*) AS people_count,
               ROUND(AVG(age), 2) AS avg_age
        FROM people
        WHERE age >= 25
        GROUP BY city
        ORDER BY people_count DESC, city ASC
        """
    ).show()

    print("\nFilter and transform using DataFrame API")
    filtered = df.filter(F.col("age") >= 30).withColumn(
        "age_group",
        F.when(F.col("age") >= 35, "35+").otherwise("30-34")
    )
    filtered.groupBy("age_group").count().orderBy(F.col("count").desc()).show()

    spark.stop()


if __name__ == "__main__":
    main()
