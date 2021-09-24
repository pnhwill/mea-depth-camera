//
//  ExperimentProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
A class to wrap everything related to fetching, creating, and deleting experiments, and to fetch data from the JSON file and save it to the Core Data store.
*/

import CoreData
import OSLog

class ExperimentProvider: FetchingDataProvider {
    
    typealias Object = Experiment
    
    private(set) var persistentContainer: PersistentContainer
    private weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    var sortKey: String = Schema.Experiment.title.rawValue
    var sortAscending: Bool = true
    
    /// Experiment JSON Data
    static let resourcesDirectory = "Resources"
    static let fileName = "MEADepthCamera_experiments"
    static let fileExtension = "json"
    let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    
    // Logging
    
    let logger = Logger(subsystem: "com.mea-lab.MEADepthCamera", category: "persistence")
    
    /**
     A fetched results controller for the Experiment entity, sorted by the sortKey property.
     */
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<Experiment> = {
        let fetchRequest: NSFetchRequest<Experiment> = Experiment.fetchRequest()
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
    
    init(with persistentContainer: PersistentContainer, fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?) {
        self.persistentContainer = persistentContainer
        self.fetchedResultsControllerDelegate = fetchedResultsControllerDelegate
    }
    
    func add(in context: NSManagedObjectContext, shouldSave: Bool, completionHandler: AddAction?) {
        context.perform {
            let experiment = Experiment(context: context)
            experiment.id = UUID()
            if shouldSave {
                self.persistentContainer.saveContext(backgroundContext: context, with: .addExperiment)
            }
            completionHandler?(experiment)
        }
    }
    
    func delete(_ experiment: Experiment, shouldSave: Bool = true, completionHandler: DeleteAction? = nil) {
        if let context = experiment.managedObjectContext {
            context.perform {
                context.delete(experiment)
                if shouldSave {
                    self.persistentContainer.saveContext(backgroundContext: context, with: .deleteExperiment)
                }
                completionHandler?(true)
            }
        } else {
            completionHandler?(false)
        }
    }
    
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
            logger.debug("Failed to receive valid directory and/or data.")
            throw JSONError.missingData
        }

        do {
            // Decode the ExperimentsJSON into a data model.
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .secondsSince1970
            let experimentJSON = try jsonDecoder.decode(ExperimentsJSON.self, from: data)
            let experimentPropertiesList = experimentJSON.propertiesList
            logger.debug("Received \(experimentPropertiesList.count) records.")

            // Import the ExperimentsJSON into Core Data.
            logger.debug("Start importing data to the store...")
            try await importExperiments(from: experimentPropertiesList)
            logger.debug("Finished importing data.")
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
            self.logger.debug("Failed to execute batch insert request.")
            throw JSONError.batchInsertError
        }
        
        do {
            try await self.importTasksForExperiments(with: experimentIDs, in: taskContext, from: propertiesList)
        } catch {
            throw error as? JSONError ?? .unexpectedError(error: error)
        }
        
        self.logger.debug("Successfully inserted data.")
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
