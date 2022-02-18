//
//  DataFetcher.swift
//  MEADepthCamera
//
//  Created by William Harrington on 1/27/22.
//

import CoreData

/// Generic implementation of `FetchingDataProvider` that initializes an `NSFetchedResultsController` and provides overridable properties for sort and section key paths.
class DataFetcher<Entity: NSManagedObject>: FetchingDataProvider {
    
    typealias Object = Entity
    
    private(set) var sortKeyPaths: [String]?
    private(set) var sectionNameKeyPath: String?
    
    private(set) var persistentContainer: PersistentContainer
    private weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?

    /// A fetched results controller for the `Entity`, sorted by the `sortKeyPaths` property and sectioned by the `sectionNameKeyPath` property.
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<Entity> = {
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest() as! NSFetchRequest<Entity>
        fetchRequest.sortDescriptors = sortKeyPaths?.map { NSSortDescriptor(key: $0, ascending: true) }

        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: persistentContainer.viewContext,
                                                    sectionNameKeyPath: sectionNameKeyPath,
                                                    cacheName: nil)
        controller.delegate = fetchedResultsControllerDelegate

        do {
            try controller.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        return controller
    }()

    required init(with persistentContainer: PersistentContainer,
                  fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?) {
        self.persistentContainer = persistentContainer
        self.fetchedResultsControllerDelegate = fetchedResultsControllerDelegate
    }
}
