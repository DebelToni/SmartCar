import groovy.transform.Field
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

// Main class to execute the data pipeline
class DataPipeline {

    @Field List<Map> dataSources
    @Field List<Transformation> transformations
    @Field List<Validation> validations
    @Field List<ErrorHandler> errorHandlers

    DataPipeline() {
        initializeComponents()
    }

    void initializeComponents() {
        // Initialize data sources with sample data
        dataSources = [
            [id: 1, name: 'Alice', age: 30, salary: 70000],
            [id: 2, name: 'Bob', age: 25, salary: 50000],
            [id: 3, name: 'Charlie', age: 35, salary: 80000],
            [id: 4, name: 'Diana', age: 28, salary: null], // Missing salary
            [id: 5, name: 'Eve', age: -1, salary: 60000] // Invalid age
        ]
        // Initialize transformations
        transformations = [
            new AddCalculatedFieldTransformation('tax', { it.salary != null ? it.salary * 0.2 : 0 }),
            new UppercaseNameTransformation(),
            new FilterInvalidAgeTransformation()
        ]
        // Initialize validations
        validations = [
            new SalaryValidation(),
            new AgeValidation()
        ]
        // Initialize error handlers
        errorHandlers = [
            new LogErrorHandler(),
            new SendAlertErrorHandler()
        ]
    }

    def execute() {
        def processedData = dataSources.collect { it.clone() }
        println "Starting data processing at ${currentTimestamp()}"
        // Apply transformations
        transformations.each { transformation ->
            processedData = transformation.apply(processedData)
        }
        // Validate data
        def invalidRecords = []
        processedData.each { record ->
            validations.each { validation ->
                if (!validation.validate(record)) {
                    record['validation_error'] = validation.getErrorMessage()
                    invalidRecords << record
                }
            }
        }
        println "Validation completed. Invalid records: ${invalidRecords.size()}"
        // Handle errors
        invalidRecords.each { record ->
            errorHandlers.each { handler ->
                handler.handle(record)
            }
        }
        // Final output
        def validRecords = processedData - invalidRecords
        println "Processing completed at ${currentTimestamp()}"
        println "Valid records:"
        validRecords.each { println it }
        println "Invalid records and their errors:"
        invalidRecords.each { println it }
    }
}

// Transformation interface
interface Transformation {
    List<Map> apply(List<Map> data)
}

// Specific transformations
class AddCalculatedFieldTransformation implements Transformation {
    String fieldName
    Closure calculation

    AddCalculatedFieldTransformation(String fieldName, Closure calculation) {
        this.fieldName = fieldName
        this.calculation = calculation
    }

    List<Map> apply(List<Map> data) {
        data.each { record ->
            record[fieldName] = calculation.call(record)
        }
        return data
    }
}

class UppercaseNameTransformation implements Transformation {
    List<Map> apply(List<Map> data) {
        data.each { record ->
            if (record.containsKey('name') && record['name'] != null) {
                record['name'] = record['name'].toString().toUpperCase()
            }
        }
        return data
    }
}

class FilterInvalidAgeTransformation implements Transformation {
    List<Map> apply(List<Map> data) {
        data.findAll { record ->
            def age = record['age']
            return age != null && age >= 0
        }
    }
}

// Validation interface
interface Validation {
    boolean validate(Map record)
    String getErrorMessage()
}

// Specific validations
class SalaryValidation implements Validation {
    String errorMessage = 'Invalid salary: must be a non-null positive number'

    boolean validate(Map record) {
        def salary = record['salary']
        return salary != null && salary > 0
    }

    String getErrorMessage() {
        return errorMessage
    }
}

class AgeValidation implements Validation {
    String errorMessage = 'Invalid age: must be a non-negative integer'

    boolean validate(Map record) {
        def age = record['age']
        return age != null && age >= 0
    }

    String getErrorMessage() {
        return errorMessage
    }
}

// ErrorHandler interface
interface ErrorHandler {
    void handle(Map record)
}

// Specific error handlers
class LogErrorHandler implements ErrorHandler {
    void handle(Map record) {
        println "LOG: Validation failed for record ID ${record['id']} with error: ${record['validation_error']}"
    }
}

class SendAlertErrorHandler implements ErrorHandler {
    void handle(Map record) {
        println "ALERT: Issue found in record ID ${record['id']}. Notification sent."
    }
}

// Utility function
def currentTimestamp() {
    return LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
}

// Run the pipeline
def pipeline = new DataPipeline()
pipeline.execute()