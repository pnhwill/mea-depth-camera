//
//  TaskProvider.swift
//  MEADepthCamera
//
//  Created by Will on 8/27/21.
//
/*
Abstract:
A class to wrap everything related to fetching, creating, and deleting tasks, and to fetch data from the JSON file and save it to the Core Data store.
*/

import CoreData
import OSLog

class TaskProvider: DataProvider {
    typealias Object = Task
    
    private(set) var persistentContainer: PersistentContainer
    private weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    var sortKey: String = Schema.Task.name.rawValue
    var sortAscending: Bool = true
    
    // MARK: Tasks Data
    
    /// Task data provided by Leif Simmatis of the University Health Network (UHN) for the VirtualSLP project. See ACKNOWLEDGMENTS.txt for additional details.
    static let resourcesDirectory = "Resources"
    static let fileName = "virtualSLP_tasks"
    static let fileExtension = "json"
    let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    
    // MARK: Logging
    
    let logger = Logger(subsystem: "com.mea-lab.MEADepthCamera", category: "persistence")
    
    /**
     A fetched results controller for the Task entity, sorted by the sortKey property.
     */
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<Task> = {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: sortAscending)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: persistentContainer.viewContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = fetchedResultsControllerDelegate
        
        do {
            try controller.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        return controller
    }()
    
    // MARK: Init

    init(with persistentContainer: PersistentContainer, fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?) {
        self.persistentContainer = persistentContainer
        self.fetchedResultsControllerDelegate = fetchedResultsControllerDelegate
    }
    
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
    func fetchTasks() throws {
        guard let url = url, let data = try? Data(contentsOf: url)
        else {
            logger.debug("Failed to receive valid directory and/or data.")
            throw JSONError.missingData
        }

        do {
            // Decode the TasksJSON into a data model.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970
            let taskJSON = try jsonDecoder.decode(TasksJSON.self, from: data)
            let taskPropertiesList = taskJSON.taskPropertiesList
            logger.debug("Received \(taskPropertiesList.count) records.")

            // Import the TasksJSON into Core Data.
            logger.debug("Start importing data to the store...")
            try importTasks(from: taskPropertiesList)
            logger.debug("Finished importing data.")
        } catch {
            throw JSONError.wrongDataFormat(error: error)
        }
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import a JSON dictionary into the Core Data store on a private queue.
    private func importTasks(from propertiesList: [TaskProperties]) throws {
        guard !propertiesList.isEmpty else {
            throw JSONError.batchInsertError
        }

        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importTasks"
        
        /// - Tag: perform
        var performSuccess = false
        taskContext.performAndWait {
            // Execute the batch insert.
            /// - Tag: batchInsertRequest
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                performSuccess = success
                return
            }
            self.logger.debug("Failed to execute batch insert request.")
        }
        if !performSuccess {
            throw JSONError.batchInsertError
        }
        
        self.logger.debug("Successfully inserted data.")
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
    
    /// Synchronously deletes given records in the Core Data store with the specified object IDs.
    func deleteTasks(identifiedBy objectIDs: [NSManagedObjectID]) {
        let viewContext = persistentContainer.viewContext
        logger.debug("Start deleting data from the store...")

        viewContext.perform {
            objectIDs.forEach { objectID in
                let task = viewContext.object(with: objectID)
                viewContext.delete(task)
            }
        }

        logger.debug("Successfully deleted data.")
    }

    /// Asynchronously deletes records in the Core Data store with the specified `Task` managed objects.
    func deleteTasks(_ tasks: [Task]) {
        let objectIDs = tasks.map { $0.objectID }
        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "deleteContext"
        taskContext.transactionAuthor = "deleteTasks"
        logger.debug("Start deleting data from the store...")

        taskContext.perform {
            // Execute the batch delete.
            let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: objectIDs)
            guard let fetchResult = try? taskContext.execute(batchDeleteRequest),
                  let batchDeleteResult = fetchResult as? NSBatchDeleteResult,
                  let success = batchDeleteResult.result as? Bool, success
            else {
                self.logger.debug("Failed to execute batch delete request.")
                return
            }
        }

        logger.debug("Successfully deleted data.")
    }
    
}
