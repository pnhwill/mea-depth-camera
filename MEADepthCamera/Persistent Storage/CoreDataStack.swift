//
//  CoreDataStack.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
A class to set up the Core Data stack, observe Core Data notifications, process persistent history, and deduplicate tags.
*/

import Foundation
import CoreData

// MARK: - Core Data Stack

/**
 Core Data stack setup including history processing.
 */
class CoreDataStack {
    
    private var persistentStore: NSPersistentStore?
    
    lazy var persistentContainer: PersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        
        let container = PersistentContainer(name: "MEADepthCamera")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        // Enable persistent store remote change notifications
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
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
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    //TODO: persistent history processing
    
}
