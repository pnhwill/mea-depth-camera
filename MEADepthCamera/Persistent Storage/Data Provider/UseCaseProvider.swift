//
//  UseCaseProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData
import OSLog

/// A class to wrap everything related to fetching, creating, and deleting use cases.
final class UseCaseProvider: DataFetcher<UseCase>, ListDataProvider {
    
    typealias Object = UseCase
    
    override var sortKeyPaths: [String]? {
        [
            Schema.UseCase.experimentTitle.rawValue,
            Schema.UseCase.date.rawValue,
        ]
    }
    
    override var sectionNameKeyPath: String? {
        Schema.UseCase.experimentTitle.rawValue
    }
    
    private let fileManager = FileManager.default
    
    private let logger = Logger.Category.persistence.logger
    
    let addInfo: ContextSaveContextualInfo = .addUseCase
    let deleteInfo: ContextSaveContextualInfo = .deleteUseCase
    
    /// Custom implementation of delete method for deleting the files on disk.
    func delete(_ useCase: UseCase, shouldSave: Bool = true, completionHandler: DeleteAction? = nil) {
        if let context = useCase.managedObjectContext {
            context.perform {
                self.trashFiles(for: useCase)
                context.delete(useCase)
                if shouldSave {
                    self.persistentContainer.saveContext(backgroundContext: context, with: self.deleteInfo)
                }
                completionHandler?(true)
            }
        } else {
            completionHandler?(false)
        }
    }
    
    private func trashFiles(for useCase: UseCase) {
        if let url = useCase.folderURL {
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } catch {
                logger.error("\(#function): Failed to trash files for use case at: \(url.path)")
            }
        }
    }
}
