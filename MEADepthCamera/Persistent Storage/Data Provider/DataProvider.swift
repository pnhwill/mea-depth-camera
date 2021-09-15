//
//  DataProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData

/// Properties and methods for classes that create and delete objects in the Core Data model.
protocol DataProvider: AnyObject {
    associatedtype Object: NSManagedObject
    typealias AddAction = (Object) -> Void
    typealias DeleteAction = (Bool) -> Void
    
    var persistentContainer: PersistentContainer { get }
    
    func add(in context: NSManagedObjectContext, shouldSave: Bool, completionHandler: AddAction?)
    
    func delete(_ object: Object, shouldSave: Bool, completionHandler: DeleteAction?)
}


/// Additional properties for DataProviders which perform Core Data fetch requests to retrieve their associated objects
protocol FetchingDataProvider: DataProvider {
    var sortKey: String { get set }
    var sortAscending: Bool { get set }
    var fetchedResultsController: NSFetchedResultsController<Object> { get }
}
