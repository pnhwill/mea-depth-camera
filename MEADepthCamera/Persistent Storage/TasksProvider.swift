//
//  TasksProvider.swift
//  MEADepthCamera
//
//  Created by Will on 8/27/21.
//
/*
Abstract:
A class to fetch data from the JSON file and save it to the Core Data store.
*/

import CoreData
import OSLog
import UIKit

class TasksProvider {
    
    // MARK: Tasks Data
    
    /// Task data provided by Leif Simmatis of the University Health Network (UHN) for the VirtualSLP project. See ACKNOWLEDGMENTS.txt for additional details.
    static let resourcesDirectory = "Resources"
    static let fileName = "virtualSLP_tasks"
    static let fileExtension = "json"
    let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)//, subdirectory: resourcesDirectory)
    
    // MARK: Logging
    
    let logger = Logger(subsystem: "com.mea-lab.MEADepthCamera", category: "persistence")
    
    // MARK: Core Data
    
    /// A shared tasks provider for use within the main app bundle.
    static let shared = TasksProvider()
    
    private let inMemory: Bool
    private var notificationToken: NSObjectProtocol?

    private init(inMemory: Bool = false) {
        self.inMemory = inMemory

        // Observe Core Data remote change notifications on the queue where the changes were made.
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { note in
            self.logger.debug("Received a persistent store remote change notification.")
            self.fetchPersistentHistory()
        }
    }
    
    deinit {
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// A peristent history token used for fetching transactions from the store.
    private var lastToken: NSPersistentHistoryToken?

    /// A persistent container to set up the Core Data stack.
    lazy var container: NSPersistentContainer = {
        /// - Tag: persistentContainer
        var persistentContainer: PersistentContainer? {
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            return appDelegate?.persistentContainer
        }
        
        guard let container = persistentContainer else {
            fatalError("Failed to retrieve a persistent store.")
        }

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable persistent store remote change notifications
        /// - Tag: persistentStoreRemoteChange
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Enable persistent history tracking
        /// - Tag: persistentHistoryTracking
        description.setOption(true as NSNumber,
                              forKey: NSPersistentHistoryTrackingKey)

//        container.loadPersistentStores { storeDescription, error in
//            if let error = error as NSError? {
//                fatalError("Unresolved error \(error), \(error.userInfo)")
//            }
//        }

        // This sample refreshes UI by consuming store changes via persistent history tracking.
        /// - Tag: viewContextMergeParentChanges
        //container.viewContext.automaticallyMergesChangesFromParent = false
        container.viewContext.name = "viewContext"
        /// - Tag: viewContextMergePolicy
        //container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        //container.viewContext.undoManager = nil
        //container.viewContext.shouldDeleteInaccessibleFaults = true
        return container
    }()
    
    /// Creates and configures a private queue context.
    private func newTaskContext() -> NSManagedObjectContext {
        // Create a private queue context.
        /// - Tag: newBackgroundContext
        let taskContext = container.newBackgroundContext()
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
            throw TaskError.missingData
        }

        do {
            // Decode the TasksJSON into a data model.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970
            let taskJSON = try jsonDecoder.decode(TasksJSON.self, from: data)
            let taskPropertiesList = taskJSON.taskPropertiesList
            logger.debug("Received \(taskPropertiesList.count) records.")

            // Import the GeoJSON into Core Data.
            logger.debug("Start importing data to the store...")
            try importTasks(from: taskPropertiesList)
            logger.debug("Finished importing data.")
        } catch {
            throw TaskError.wrongDataFormat(error: error)
        }
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import a JSON dictionary into the Core Data store on a private queue.
    private func importTasks(from propertiesList: [TaskProperties]) throws {
        guard !propertiesList.isEmpty else {
            throw TaskError.batchInsertError
        }

        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importTasks"
        
        /// - Tag: perform
        taskContext.performAndWait {
            // Execute the batch insert.
            /// - Tag: batchInsertRequest
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                self.logger.debug("Successfully inserted data.")
                return
            }
            self.logger.debug("Failed to execute batch insert request.")
        }
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
        let viewContext = container.viewContext
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
    
    func fetchPersistentHistory() {
        fetchPersistentHistoryTransactionsAndChanges()
    }
    
    private func fetchPersistentHistoryTransactionsAndChanges() {
        let taskContext = newTaskContext()
        taskContext.name = "persistentHistoryContext"
        logger.debug("Start fetching persistent history changes from the store...")

        taskContext.performAndWait {
            // Execute the persistent history change since the last transaction.
            /// - Tag: fetchHistory
            let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
            let historyResult = try? taskContext.execute(changeRequest) as? NSPersistentHistoryResult
            if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
               !history.isEmpty {
                self.mergePersistentHistoryChanges(from: history)
                return
            }

            self.logger.debug("No persistent history transactions found.")
        }

        logger.debug("Finished merging history changes.")
    }

    private func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        self.logger.debug("Received \(history.count) persistent history transactions.")
        // Update view context with objectIDs from history change request.
        /// - Tag: mergeChanges
        let viewContext = container.viewContext
        viewContext.perform {
            for transaction in history {
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                self.lastToken = transaction.token
            }
        }
    }
    
}
