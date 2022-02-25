//
//  DataProvider.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import CoreData

// MARK: DataProvider
/// Properties and methods for classes that interact with `NSManagedObject` subclasses in the Core Data model.
protocol DataProvider: AnyObject {
    associatedtype Object: NSManagedObject
    var persistentContainer: PersistentContainer { get }
}

extension DataProvider {
    /// Utility method for fetching a single object with the given `UUID`.
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
/// Additional properties for any `DataProvider` that performs Core Data fetch requests to retrieve their associated objects.
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
/// Additional methods for classes that create objects in the Core Data model.
protocol AddingDataProvider: DataProvider {
    typealias AddAction = (Object) -> Void
    var addInfo: ContextSaveContextualInfo { get }
    func add(in context: NSManagedObjectContext, shouldSave: Bool, completionHandler: AddAction?)
}

extension AddingDataProvider {
    func add(in context: NSManagedObjectContext, shouldSave: Bool = true, completionHandler: AddAction? = nil) {
        context.perform {
            let newObject = Object(context: context)
            if shouldSave {
                self.persistentContainer.saveContext(backgroundContext: context, with: self.addInfo)
            }
            completionHandler?(newObject)
        }
    }
}

// MARK: DeletingDataProvider
/// Additional methods for classes that delete objects in the Core Data model.
protocol DeletingDataProvider: DataProvider {
    typealias DeleteAction = (Bool) -> Void
    var deleteInfo: ContextSaveContextualInfo { get }
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
/// All required conformances for DataProviders that interact with Core Data objects through the list column.
protocol ListDataProvider:
    FetchingDataProvider,
    AddingDataProvider,
    DeletingDataProvider
where Object: ListObject {}
