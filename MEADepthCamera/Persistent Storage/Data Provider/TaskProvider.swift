//
//  TaskProvider.swift
//  MEADepthCamera
//
//  Created by Will on 8/27/21.
//

import CoreData
import OSLog

/// A class to wrap everything related to fetching, creating, and deleting tasks, and to fetch data from the JSON file and save it to the Core Data store.
final class TaskProvider: DataFetcher<Task>, ListDataProvider {
    typealias Object = Task
    
    override var sortKeyPaths: [String]? {
        [
            Schema.Task.isDefaultString.rawValue,
            Schema.Task.name.rawValue,
        ]
    }
    override var sectionNameKeyPath: String? {
        Schema.Task.isDefaultString.rawValue
    }
    
    let addInfo: ContextSaveContextualInfo = .addTask
    let deleteInfo: ContextSaveContextualInfo = .deleteTask
    
    private let logger = Logger.Category.persistence.logger
    
    // MARK: Tasks Data
    /// Task data provided by Leif Simmatis of the University Health Network (UHN) for the VirtualSLP project. See ACKNOWLEDGMENTS.txt for additional details.
    private static let fileName = "virtualSLP_tasks"
    private static let fileExtension = "json"
    private let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    
//    func copy(_ task: Task, completionHandler: AddAction?) {
////        let context = persistentContainer.newBackgroundContext()
//        let context = task.managedObjectContext ?? persistentContainer.viewContext
//        add(in: context) { newTask in
//            newTask.name = task.name
//            newTask.fileNameLabel = task.fileNameLabel
//            newTask.instructions = task.name
//            newTask.modality = task.modality
//            completionHandler?(newTask)
//        }
//    }
    
}

// MARK: JSON Fetching & Import
extension TaskProvider {
    /// Creates and configures a private queue context.
    private func newTaskContext() -> NSManagedObjectContext {
        // Create a private queue context.
        /// - Tag: newBackgroundContext
        let taskContext = persistentContainer.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }
    
    /// Fetches the task list from the JSON file, and imports it into Core Data.
    func fetchJSONData() async throws {
        guard let url = url, let data = try? Data(contentsOf: url) else {
            logger.error("Failed to receive valid directory and/or Task data.")
            throw JSONError.missingData
        }

        do {
            // Decode the TasksJSON into a data model.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970
            let taskJSON = try jsonDecoder.decode(TasksJSON.self, from: data)
            let taskPropertiesList = taskJSON.taskPropertiesList
            logger.info("Received \(taskPropertiesList.count) Task records.")

            // Import the TasksJSON into Core Data.
            logger.info("Start importing Task data to the store...")
            try await importTasks(from: taskPropertiesList)
            logger.info("Finished importing Task data.")
        } catch {
            throw JSONError.wrongDataFormat(error: error)
        }
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import a JSON dictionary into the Core Data store on a private queue.
    private func importTasks(from propertiesList: [TaskProperties]) async throws {
        guard !propertiesList.isEmpty else { return }

        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importTasks"
        
        /// - Tag: performAndWait
        try await taskContext.perform {
            // Execute the batch insert.
            /// - Tag: batchInsertRequest
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                return
            }
            self.logger.error("Failed to execute Task batch insert request.")
            throw JSONError.batchInsertError
        }
        
        self.logger.info("Successfully inserted Task data.")
    }
    
    private func newBatchInsertRequest(with propertyList: [TaskProperties]) -> NSBatchInsertRequest {
        var index = 0
        let total = propertyList.count

        // Provide one dictionary at a time when the closure is called.
        let batchInsertRequest = NSBatchInsertRequest(entity: Task.entity(), dictionaryHandler: { dictionary in
            guard index < total else { return true }
            dictionary.addEntries(from: propertyList[index].dictionaryValue)
            index += 1
            return false
        })
        return batchInsertRequest
    }
    
//    /// Synchronously deletes given records in the Core Data store with the specified object IDs.
//    func deleteTasks(identifiedBy objectIDs: [NSManagedObjectID]) {
//        let viewContext = persistentContainer.viewContext
//        logger.debug("Start deleting data from the store...")
//
//        viewContext.perform {
//            objectIDs.forEach { objectID in
//                let task = viewContext.object(with: objectID)
//                viewContext.delete(task)
//            }
//        }
//
//        logger.debug("Successfully deleted data.")
//    }
//
//    /// Asynchronously deletes records in the Core Data store with the specified `Task` managed objects.
//    func deleteTasks(_ tasks: [Task]) {
//        let objectIDs = tasks.map { $0.objectID }
//        let taskContext = newTaskContext()
//        // Add name and author to identify source of persistent history changes.
//        taskContext.name = "deleteContext"
//        taskContext.transactionAuthor = "deleteTasks"
//        logger.debug("Start deleting data from the store...")
//
//        taskContext.perform {
//            // Execute the batch delete.
//            let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: objectIDs)
//            guard let fetchResult = try? taskContext.execute(batchDeleteRequest),
//                  let batchDeleteResult = fetchResult as? NSBatchDeleteResult,
//                  let success = batchDeleteResult.result as? Bool, success
//            else {
//                self.logger.debug("Failed to execute batch delete request.")
//                return
//            }
//        }
//
//        logger.debug("Successfully deleted data.")
//    }
    
}
