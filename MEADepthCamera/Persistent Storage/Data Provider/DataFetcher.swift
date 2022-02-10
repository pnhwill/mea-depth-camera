//
//  DataFetcher.swift
//  MEADepthCamera
//
//  Created by William Harrington on 1/27/22.
//

import CoreData

class DataFetcher<Model: NSManagedObject>: FetchingDataProvider {
    
    typealias Object = Model
    
    private(set) var sortKeyPaths: [String]?
    private(set) var sectionNameKeyPath: String?
    
    private(set) var persistentContainer: PersistentContainer
    private weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?

    /// A fetched results controller for the Model entity, sorted by the sortKey property.
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<Model> = {
        let fetchRequest: NSFetchRequest<Model> = Model.fetchRequest() as! NSFetchRequest<Model>
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
