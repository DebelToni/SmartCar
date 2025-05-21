import groovy.transform.Field
import java.util.concurrent.*

// Define a class for processing data items
class DataProcessor {
    def process(item) {
        // Simulate processing time and potential error
        def processingTime = new Random().nextInt(300) + 100 // 100 to 400 ms
        Thread.sleep(processingTime)
        if (new Random().nextDouble() < 0.1) { // 10% chance to throw error
            throw new RuntimeException("Error processing item: ${item.id}")
        }
        return "Processed ${item.content}"
    }
}

// Define a data item class
class DataItem {
    def id
    def content
}

// Generate a list of sample data items
def generateDataItems(count) {
    def items = []
    (1..count).each {
        items << new DataItem(id: it, content: "Data_${it}")
    }
    return items
}

// Initialize thread pool for concurrent processing
def threadPool = Executors.newFixedThreadPool(10)

// Initialize data processor
def processor = new DataProcessor()

// Generate data
def dataItems = generateDataItems(50)

// Prepare structures to hold futures and results
@Field def futures = []
@Field def results = [:]
@Field def errors = []

// Submit tasks to thread pool
dataItems.each { item ->
    def future = threadPool.submit({
        try {
            def result = processor.process(item)
            results[item.id] = result
        } catch (Exception e) {
            errors << [id: item.id, error: e.message]
        }
    } as Callable)
    futures << future
}

// Wait for all tasks to complete
futures.each { it.get() }

// Shutdown thread pool
threadPool.shutdown()

// Generate summary report
def report = new StringBuilder()
report << "\n=== Data Processing Summary ===\n"
report << "Total items: ${dataItems.size()}\n"
report << "Successfully processed: ${results.size()}\n"
report << "Errors encountered: ${errors.size()}\n"
if (errors) {
    report << "\nErrors Details:\n"
    errors.each { error ->
        report << "Item ID: ${error.id}, Error: ${error.error}\n"
    }
}
println report.toString()

// Save results and errors to files
new File('processed_results.txt').withWriter { writer ->
    results.each { id, result ->
        writer.writeLine("ID: ${id}, Result: ${result}")
    }
}

new File('error_log.txt').withWriter { writer ->
    errors.each { error ->
        writer.writeLine("ID: ${error.id}, Error: ${error.error}")
    }
}
