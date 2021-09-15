//
//  OutputFileProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/2/21.
//
/*
Abstract:
A class to wrap everything related to creating, and deleting output files, and saving and deleting file data.
*/

import CoreData

class OutputFileProvider: DataProvider {
    
    typealias Object = OutputFile
    
    private(set) var persistentContainer: PersistentContainer
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
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
    
    func delete(_ outputFile: OutputFile, shouldSave: Bool = true, completionHandler: DeleteAction? = nil) {
        if let context = outputFile.managedObjectContext {
            context.perform {
                context.delete(outputFile)
                if shouldSave {
                    self.persistentContainer.saveContext(backgroundContext: context, with: .deleteOutputFile)
                }
                completionHandler?(true)
            }
        } else {
            completionHandler?(false)
        }
    }
    
}
