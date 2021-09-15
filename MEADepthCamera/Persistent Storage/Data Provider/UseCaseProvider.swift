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

class UseCaseProvider: FetchingDataProvider {
    
    typealias Object = UseCase
    
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
    
    init(with persistentContainer: PersistentContainer, fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?) {
        self.persistentContainer = persistentContainer
        self.fetchedResultsControllerDelegate = fetchedResultsControllerDelegate
    }
    
    func add(in context: NSManagedObjectContext, shouldSave: Bool = true, completionHandler: AddAction? = nil) {
        context.perform {
            let useCase = UseCase(context: context)
            useCase.date = Date()
            useCase.id = UUID()
            if shouldSave {
                self.persistentContainer.saveContext(backgroundContext: context, with: .addUseCase)
            }
            completionHandler?(useCase)
        }
    }
    
    func delete(_ useCase: UseCase, shouldSave: Bool = true, completionHandler: DeleteAction? = nil) {
        if let context = useCase.managedObjectContext {
            context.perform {
                context.delete(useCase)
                if shouldSave {
                    self.persistentContainer.saveContext(backgroundContext: context, with: .deleteUseCase)
                }
                completionHandler?(true)
            }
        } else {
            completionHandler?(false)
        }
    }

}
