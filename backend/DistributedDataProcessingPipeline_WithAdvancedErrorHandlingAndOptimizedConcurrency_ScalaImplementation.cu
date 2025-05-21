import scala.concurrent.{Future, ExecutionContext}
import scala.util.{Failure, Success}
import java.util.concurrent.Executors
import scala.collection.mutable

// Define a case class for data items
case class DataItem(id: Int, value: String, timestamp: Long)

// Custom exception for processing errors
class ProcessingException(message: String) extends Exception(message)

// Object containing the data processing pipeline
object DataProcessingPipeline {
  // Initialize an execution context with a fixed thread pool
  private val threadPool = Executors.newFixedThreadPool(8)
  implicit val ec: ExecutionContext = ExecutionContext.fromExecutor(threadPool)

  // Simulate data source
  def fetchData(count: Int): Seq[DataItem] = {
    (1 to count).map { id =>
      DataItem(id, s"value_$id", System.currentTimeMillis())
    }
  }

  // Transform data item with potential for failure
  def transformData(item: DataItem): Future[DataItem] = Future {
    if (item.id % 15 == 0) {
      throw new ProcessingException(s"Failed to process item with id: ${item.id}")
    } else if (item.id % 5 == 0) {
      // Simulate a transient error
      throw new RuntimeException(s"Transient error on item: ${item.id}")
    } else {
      // Simulate processing delay
      Thread.sleep(50)
      item.copy(value = item.value.toUpperCase())
    }
  }

  // Filter function with retries for transient errors
  def safeTransform(item: DataItem, retries: Int = 3): Future[DataItem] = {
    transformData(item).recoverWith {
      case e: RuntimeException if retries > 0 =>
        println(s"Retrying item ${item.id} due to transient error: ${e.getMessage}")
        safeTransform(item, retries - 1)
      case e: ProcessingException =>
        println(s"Processing failed for item ${item.id}: ${e.getMessage}")
        Future.failed(e)
    }
  }

  // Aggregate data based on some criteria
  def aggregateData(items: Seq[DataItem]): Map[String, Int] = {
    items.groupBy(_.value).mapValues(_.size)
  }

  // Main processing function
  def processDataBatch(batchSize: Int): Future[Unit] = {
    val rawData = fetchData(batchSize)
    val processedFutures: Seq[Future[DataItem]] = rawData.map { item =>
      safeTransform(item).recover {
        case e: ProcessingException =>
          println(s"Skipping item ${item.id} due to processing error.")
          null
      }
    }
    // Wait for all futures to complete
    Future.sequence(processedFutures).map { processedItems =>
      val successfulItems = processedItems.filter(_ != null)
      val aggregationResult = aggregateData(successfulItems)
      println(s"Aggregation result: $aggregationResult")
    }
  }

  def runPipeline(): Unit = {
    val batchCount = 5
    val batchSize = 100
    val processingFutures = (1 to batchCount).map { _ =>
      processDataBatch(batchSize)
    }
    // Await completion of all batches
    import scala.concurrent.Await
    import scala.concurrent.duration._
    Await.result(Future.sequence(processingFutures), 10.minutes)
    println("Data processing pipeline completed.")
    threadPool.shutdown()
  }
}

// Entry point
object Main extends App {
  DataProcessingPipeline.runPipeline()
}