import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._

object SparkSqlDemo {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("SparkSQLSandbox")
      .master("local[*]")
      .getOrCreate()

    import spark.implicits._

    val data = Seq(
      ("Alice", 34, "New York"),
      ("Bob", 29, "Boston"),
      ("Charlie", 41, "Seattle"),
      ("Diana", 28, "Boston"),
      ("Ethan", 36, "New York"),
      ("Fiona", 25, "Austin")
    )

    val people = data.toDF("name", "age", "city")
    people.createOrReplaceTempView("people")

    println("\nRaw data:")
    people.show()

    println("\nSQL query: cities with average age and count")
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
    ).show(false)

    println("\nFilter and transform using the DataFrame API")
    val filtered = people
      .filter(col("age") >= 30)
      .withColumn("age_group", when(col("age") >= 35, "35+").otherwise("30-34"))

    filtered.groupBy("age_group").count().orderBy(col("count").desc).show()

    spark.stop()
  }
}
