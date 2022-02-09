//
//  CoreDataStack.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import Foundation
import CoreData
import OSLog

/// Sets up the Core Data stack, observes Core Data notifications, processed persistent history, and deduplicates.
class CoreDataStack: ObservableObject {
    
    @Published private(set) var isLoaded: Bool = false
    
    // MARK: Persistent Container
    /// The persistent container for the application. This implementation
    /// creates and returns a container, having loaded the store for the
    /// application to it. This property is optional since there are legitimate
    /// error conditions that could cause the creation of the store to fail.
    lazy var persistentContainer: PersistentContainer = {
        
        // Register the transformer at the very beginning.
        // .processorSettingsToDataTransformer is a name defined with an NSValueTransformerName extension.
        ValueTransformer.setValueTransformer(ProcessorSettingsToDataTransformer(), forName: .processorSettingsToDataTransformer)
        
        let container = PersistentContainer(name: Bundle.main.applicationName)
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        // Enable persistent history tracking
        description.setOption(true as NSNumber,
                              forKey: NSPersistentHistoryTrackingKey)
        
        // Load the persistent store
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("###\(#function): Failed to load persistent stores: \(error), \(error.userInfo)")
            }
        })
        
        // Set viewContext properties
        container.viewContext.name = "viewContext"
        container.viewContext.automaticallyMergesChangesFromParent = true
//        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//        container.viewContext.mergePolicy = NSRollbackMergePolicy
        
        // Pin the viewContext to the current generation token and set it to keep itself up to date with local changes.
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("###\(#function): Failed to pin viewContext to the current generation:\(error)")
        }
        
        return container
    }()
    
    private let logger = Logger.Category.persistence.logger
    
    // MARK: Load Experiments from JSON
    /// Asynchronously load the stored JSON data into the Core Data store.
    func importDataIfNeeded() {
        _Concurrency.Task {
            await loadExperiments()
            isLoaded = true
        }
    }
    
    private func loadExperiments() async {
        // Core Data provider to load experiments
        let container = persistentContainer
        let provider = ExperimentProvider(with: container, fetchedResultsControllerDelegate: nil)
        
        do {
            try await provider.fetchJSONData()
        } catch {
            let error = error as? JSONError ?? .unexpectedError(error: error)
            fatalError("Failed to fetch experiments with error \(error): \(error.localizedDescription)")
        }
    }
    
    // MARK: Persistent History Token
    /**
     Track the last history token processed for a store, and write its value to file.
     
     The historyQueue reads the token when executing operations, and updates it after processing is complete.
     */
//    private var lastHistoryToken: NSPersistentHistoryToken? = nil {
//        didSet {
//            guard let token = lastHistoryToken,
//                let data = try? NSKeyedArchiver.archivedData( withRootObject: token, requiringSecureCoding: true) else { return }
//
//            do {
//                try data.write(to: tokenFile)
//            } catch {
//                print("###\(#function): Failed to write token data. Error = \(error)")
//            }
//        }
//    }
    
    /**
     The file URL for persisting the persistent history token.
    */
//    private lazy var tokenFile: URL = {
//        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("MEADepthCamera", isDirectory: true)
//        if !FileManager.default.fileExists(atPath: url.path) {
//            do {
//                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                print("###\(#function): Failed to create persistent container URL. Error = \(error)")
//            }
//        }
//        return url.appendingPathComponent("token.data", isDirectory: false)
//    }()
    
    /**
     An operation queue for handling history processing tasks: watching changes, deduplicating tags, and triggering UI updates if needed.
     */
//    private lazy var historyQueue: OperationQueue = {
//        let queue = OperationQueue()
//        queue.maxConcurrentOperationCount = 1
//        return queue
//    }()
    
    // MARK: INIT
    init() {
        // Load the last token from the token file.
//        if let tokenData = try? Data(contentsOf: tokenFile) {
//            do {
//                lastHistoryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: tokenData)
//            } catch {
//                print("###\(#function): Failed to unarchive NSPersistentHistoryToken. Error = \(error)")
//            }
//        }
    }
}

