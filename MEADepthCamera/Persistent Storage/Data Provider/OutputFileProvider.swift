//
//  OutputFileProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/2/21.
//

import CoreData

/// A class to wrap everything related to creating, and deleting output files, and saving and deleting file data.
class OutputFileProvider: AddingDataProvider, DeletingDataProvider {
    
    typealias Object = OutputFile
    
    private(set) var persistentContainer: PersistentContainer
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    /// Custom implementation of add method which executes synchronously.
    func add(in context: NSManagedObjectContext, shouldSave: Bool = true, completionHandler: AddAction? = nil) {
        context.performAndWait {
            let outputFile = OutputFile(context: context)
            outputFile.id = UUID()
            if shouldSave {
                self.persistentContainer.saveContext(backgroundContext: context, with: .addOutputFile)
            }
            completionHandler?(outputFile)
        }
    }
    
}
