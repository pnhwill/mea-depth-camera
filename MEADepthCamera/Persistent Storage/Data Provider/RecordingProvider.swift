//
//  RecordingProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData
import OSLog

/// A class to wrap everything related to creating and deleting recordings.
final class RecordingProvider: AddingDataProvider, DeletingDataProvider {
    
    typealias Object = Recording
    
    private(set) var persistentContainer: PersistentContainer
    
    private let fileManager = FileManager.default
    
    private let logger = Logger.Category.persistence.logger
    
    init(with persistentContainer: PersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    /// Custom implementation of delete method for deleting the files on disk.
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
                debugPrint("AAAAA")
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                debugPrint("BBBBBB")
            } catch {
                logger.error("\(#function): Failed to trash files for recording at: \(url.path)")
            }
        }
    }
    
}
