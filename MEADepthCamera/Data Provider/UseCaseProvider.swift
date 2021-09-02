//
//  UseCaseProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
A class to wrap everything related to fetching, creating, and deleting use cases.
*/

import CoreData

class UseCaseProvider: DataProvider {
    
    typealias Entity = UseCase
    
    private(set) var persistentContainer: PersistentContainer
    private weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    var sortKey: String = Schema.UseCase.title.rawValue
    var sortAscending: Bool = true
    
    /**
     A fetched results controller for the UseCase entity, sorted by the sortKey property.
     */
    private(set) lazy var fetchedResultsController: NSFetchedResultsController<UseCase> = {
        let fetchRequest: NSFetchRequest<UseCase> = UseCase.fetchRequest()
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
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    //func add
    
    //func delete

}
