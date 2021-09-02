//
//  ExperimentProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
A class to wrap everything related to fetching, creating, and deleting experiments.
*/

import CoreData

class ExperimentProvider: DataProvider {
    
    typealias Entity = Experiment
    
    private(set) var persistentContainer: PersistentContainer
    private weak var fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?
    var sortKey: String = Schema.Experiment.title.rawValue
    var sortAscending: Bool = true
    
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
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
}
