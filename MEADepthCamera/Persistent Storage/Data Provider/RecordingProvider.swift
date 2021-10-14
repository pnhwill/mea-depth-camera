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
    
    private let fileManager = FileManager.default
    
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
                self.trashFiles(for: recording)
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
    
    private func trashFiles(for recording: Recording) {
        if let url = recording.folderURL {
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } catch {
                debugPrint("###\(#function): Failed to trash files for recording at: \(url.path)")
            }
        }
    }
    
}
