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

class ExperimentProvider: DataProvider {
    
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
    func fetchExperiments() throws {
        guard let url = url, let data = try? Data(contentsOf: url)
        else {
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
            try importExperiments(from: experimentPropertiesList)
            logger.debug("Finished importing data.")
        } catch {
            throw JSONError.wrongDataFormat(error: error)
        }
    }
    
    /// Uses `NSBatchInsertRequest` (BIR) to import a JSON dictionary into the Core Data store on a private queue.
    private func importExperiments(from propertiesList: [ExperimentProperties]) throws {
        guard !propertiesList.isEmpty else {
            throw JSONError.batchInsertError
        }

        let taskContext = newTaskContext()
        // Add name and author to identify source of persistent history changes.
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importExperiments"
        
        var performSuccess = false
        taskContext.performAndWait {
            // Execute the batch insert.
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
}
