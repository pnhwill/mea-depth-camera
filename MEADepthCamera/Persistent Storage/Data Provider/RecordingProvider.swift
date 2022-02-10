//
//  RecordingProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData
import OSLog

/// A class to wrap everything related to creating and deleting recordings.
class RecordingProvider: OldDataProvider {
    
    typealias Object = Recording
    
    private(set) var persistentContainer: PersistentContainer
    
    private let fileManager = FileManager.default
    
    private let logger = Logger.Category.persistence.logger
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    func add(in context: NSManagedObjectContext, shouldSave: Bool = true, completionHandler: AddAction? = nil) {
        context.perform {
            let recording = Recording(context: context)
            let id = UUID()
            recording.id = id
            recording.isProcessed = false
            self.logger.info("Recording \(id.uuidString) added to NSManagedObjectContext.")
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
                logger.error("\(#function): Failed to trash files for recording at: \(url.path)")
            }
        }
    }
    
}
