//
//  RecordingProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
A class to wrap everything related to creating and deleting recordings.
*/

import CoreData

class RecordingProvider: DataProvider {
    
    typealias Object = Recording
    
    private(set) var persistentContainer: PersistentContainer
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    func add(in context: NSManagedObjectContext, shouldSave: Bool = true, completionHandler: AddAction? = nil) {
        context.perform {
            let recording = Recording(context: context)
            recording.id = UUID()
            recording.isProcessed = false
            if shouldSave {
                self.persistentContainer.saveContext(backgroundContext: context, with: .addRecording)
            }
            completionHandler?(recording)
        }
    }
    
    func delete(_ recording: Recording, shouldSave: Bool = true, completionHandler: DeleteAction? = nil) {
        if let context = recording.managedObjectContext {
            context.perform {
                context.delete(recording)
                if shouldSave {
                    self.persistentContainer.saveContext(backgroundContext: context, with: .deleteRecording)
                }
                completionHandler?(true)
            }
        } else {
            completionHandler?(false)
        }
    }
    
}
