//
//  ExperimentProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData
import OSLog

/// A class to wrap everything related to fetching, creating, and deleting experiments, and to fetch data from the JSON file and save it to the Core Data store.
final class ExperimentProvider: DataFetcher<Experiment> {
    typealias Object = Experiment
    
    override var sortKeyPaths: [String]? {
        [Schema.Experiment.title.rawValue]
    }
    //    override var sectionNameKeyPath: String? {
    //        Schema.Entity.isDefaultString.rawValue
    //    }
    
    private let logger = Logger.Category.persistence.logger
    
    /// Experiment JSON Data
    private static let fileName = "MEADepthCamera_experiments"
    private static let fileExtension = "json"
    private let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    
}

// MARK: JSON Fetching & Import
extension ExperimentProvider {
    /// Creates and configures a private queue context.
    private func newTaskContext() -> NSManagedObjectContext {
        // Create a private queue context.
        let taskContext = persistentContainer.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        taskContext.undoManager = nil
        return taskContext
    }
    
    /// Fetches the experiments list from the JSON file, and imports it into Core Data.
    func fetchJSONData() async throws {
        guard let url = url, let data = try? Data(contentsOf: url) else {
            logger.error("Failed to receive valid directory and/or Experiment data.")
            throw JSONError.missingData
        }

        do {
            // Decode the ExperimentsJSON into a data model.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970
            let experimentJSON = try jsonDecoder.decode(ExperimentsJSON.self, from: data)
            let experimentPropertiesList = experimentJSON.propertiesList
            logger.info("Received \(experimentPropertiesList.count) Experiment records.")

            // Import the ExperimentsJSON into Core Data.
            logger.info("Start importing Experiment data to the store...")
            try await importExperiments(from: experimentPropertiesList)
            logger.info("Finished importing Experiment data.")
        } catch {
            throw JSONError.wrongDataFormat(error: error)
        }
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import a JSON dictionary into the Core Data store on a private queue.
    private func importExperiments(from propertiesList: [ExperimentProperties]) async throws {
        guard !propertiesList.isEmpty else { return }

        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importExperiments"
        
        let experimentIDs: [NSManagedObjectID] = try await taskContext.perform {
            // Execute the batch insert.
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            batchInsertRequest.resultType = .objectIDs
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let experimentIDs = batchInsertResult.result as? [NSManagedObjectID] {
                return experimentIDs
            }
            self.logger.error("Failed to execute Experiment batch insert request.")
            throw JSONError.batchInsertError
        }
        
        do {
            try await self.importTasksForExperiments(with: experimentIDs, in: taskContext, from: propertiesList)
        } catch {
            throw error as? JSONError ?? .unexpectedError(error: error)
        }
        
        self.logger.info("Successfully inserted Experiment data.")
    }
    
    private func newBatchInsertRequest(with propertyList: [ExperimentProperties]) -> NSBatchInsertRequest {
        var index = 0
        let total = propertyList.count

        // Provide one dictionary at a time when the closure is called.
        let batchInsertRequest = NSBatchInsertRequest(entity: Experiment.entity(), dictionaryHandler: { dictionary in
            guard index < total else { return true }
            dictionary.addEntries(from: propertyList[index].dictionaryValue)
            index += 1
            return false
        })
        
        return batchInsertRequest
    }
    
    private func importTasksForExperiments(with objectIDs: [NSManagedObjectID], in context: NSManagedObjectContext, from propertiesList: [ExperimentProperties]) async throws {
        for experimentID in objectIDs {
            if let experiment = context.object(with: experimentID) as? Experiment,
               let experimentProperties = propertiesList.first(where: { $0.dictionaryValue["title"] as? String == experiment.title }) {
                do {
                    try await updateTaskList(for: experiment, in: context, with: experimentProperties)
                } catch {
                    throw error as? JSONError ?? .unexpectedError(error: error)
                }
            }
        }
        persistentContainer.saveContext(backgroundContext: context)
    }
    
    private func updateTaskList(for experiment: Experiment, in context: NSManagedObjectContext, with experimentProperties: ExperimentProperties) async throws {
        let dictionary = experimentProperties.dictionaryValue
        guard let newTasks = dictionary["tasks"] as? [String] else {
            throw JSONError.missingData
        }
        let taskProvider = TaskProvider(with: persistentContainer, fetchedResultsControllerDelegate: nil)
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()

        do {
            try await taskProvider.fetchJSONData()
            let fetchedTasks = try context.fetch(fetchRequest)
            for taskName in newTasks {
                if let newTask = fetchedTasks.first(where: { $0.fileNameLabel == taskName }) {
                    experiment.addToTasks(newTask)
                }
            }
        } catch {
            throw error as? JSONError ?? .unexpectedError(error: error)
        }
    }
    
}
