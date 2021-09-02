//
//  PersistentContainer.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import CoreData

class PersistentContainer: NSPersistentContainer {
    
    // MARK: Core Data Saving support
    
    func saveContext(backgroundContext: NSManagedObjectContext? = nil) {
        let context = backgroundContext ?? viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch let error as NSError {
            print("Error: \(error), \(error.userInfo)")
        }
    }
    
//    func backgroundContext() -> NSManagedObjectContext {
//        let context = newBackgroundContext()
//        return context
//    }
    
    // func handleSavingError
    
}
