//
//  DataProvider.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import CoreData

// MARK: DataProvider

protocol DataProvider: AnyObject {
    associatedtype Object: NSManagedObject
    var persistentContainer: PersistentContainer { get }
}

extension DataProvider {
    static func fetchObject(with id: UUID) -> Object? {
        let context = AppDelegate.shared.coreDataStack.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Object> = Object.fetchRequest() as! NSFetchRequest<Object>
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = NSPredicate(format: "%K == %@", Schema.Shared.id.rawValue, id as CVarArg)
        do {
            let result = try context.fetch(fetchRequest).first
            return result
        } catch {
            debugPrint("###\(#function): Failed to performFetch: \(error)")
        }
        return nil
    }
}

// MARK: FetchingDataProvider

protocol FetchingDataProvider: DataProvider {
    var fetchedResultsController: NSFetchedResultsController<Object> { get }
    init(with persistentContainer: PersistentContainer, fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate?)
}

extension FetchingDataProvider {
    init(with persistentContainer: PersistentContainer = AppDelegate.shared.coreDataStack.persistentContainer,
         fetchedResultsControllerDelegate: NSFetchedResultsControllerDelegate? = nil) {
        self.init(
            with: persistentContainer,
            fetchedResultsControllerDelegate: fetchedResultsControllerDelegate)
    }
}

// MARK: AddingDataProvider

protocol AddingDataProvider: DataProvider {
    typealias AddAction = (Object) -> Void
    func add(in context: NSManagedObjectContext, shouldSave: Bool, completionHandler: AddAction?)
}

extension AddingDataProvider {
    func add(in context: NSManagedObjectContext, shouldSave: Bool = true, completionHandler: AddAction? = nil) {
        context.perform {
            let newObject = Object(context: context)
            if shouldSave {
                self.persistentContainer.saveContext(backgroundContext: context)
            }
            completionHandler?(newObject)
        }
    }
}

// MARK: DeletingDataProvider

protocol DeletingDataProvider: DataProvider {
    typealias DeleteAction = (Bool) -> Void
    func delete(_ object: Object, shouldSave: Bool, completionHandler: DeleteAction?)
}

extension DeletingDataProvider {
    func delete(_ object: Object, shouldSave: Bool = true, completionHandler: DeleteAction? = nil) {
        if let context = object.managedObjectContext {
            context.perform {
                context.delete(object)
                if shouldSave {
                    self.persistentContainer.saveContext(backgroundContext: context)
                }
                completionHandler?(true)
            }
        } else {
            completionHandler?(false)
        }
    }
}

// MARK: ListDataProvider

protocol ListDataProvider:
    FetchingDataProvider,
    AddingDataProvider,
    DeletingDataProvider
where Object: ListObject {}
