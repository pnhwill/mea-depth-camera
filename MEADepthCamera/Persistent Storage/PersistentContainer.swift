//
//  PersistentContainer.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import CoreData
import OSLog

class PersistentContainer: NSPersistentContainer {
    
    private let logger = Logger.Category.persistence.logger
    
    // MARK: Core Data Saving support
    
    /// Save a context, or handle the save error (for example, when there data inconsistency or low memory).
    func saveContext(backgroundContext: NSManagedObjectContext? = nil, with contextualInfo: ContextSaveContextualInfo? = nil) {
        let context = backgroundContext ?? viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            handleSavingError(error, contextualInfo: contextualInfo)
            return
        }
        logger.info("Successfully saved the NSManagedObjectContext to the store.")
    }
    
    /// Handles save error by presenting an alert.
    private func handleSavingError(_ error: Error, contextualInfo: ContextSaveContextualInfo?) {
        logger.error("Context saving error when \(contextualInfo?.rawValue ?? "UNKNOWN"): \(String(describing: error))")
        if let contextualInfo = contextualInfo {
            DispatchQueue.main.async {
                guard let mainWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = mainWindowScene.windows.first,
                      let viewController = window.rootViewController else { return }
                
                let message = "Core Data Saving Error: Failed to save the context when \(contextualInfo.rawValue)."
                
                let alertController = Alert.displayError(message: message, completion: nil)
                
                viewController.alert(alertController: alertController)
            }
        }
    }
}

// MARK: ContextSaveContextualInfo

/// Contextual information for handling Core Data context save errors.
enum ContextSaveContextualInfo: String {
    case addUseCase = "adding a use case"
    case deleteUseCase = "deleting a use case"
    case updateUseCase = "saving use case details"
    case addRecording = "adding a recording"
    case updateRecording = "saving recording details"
    case deleteRecording = "deleting a recording"
    case addOutputFile = "adding an output file"
    case updateOutputFile = "saving output file details"
    case deleteOutputFile = "deleting an output file"
    case addExperiment = "adding an experiment"
    case updateExperiment = "saving experiment details"
    case deleteExperiment = "deleting an experiment"
    case addTask = "adding a task"
    case updateTask = "saving task details"
    case deleteTask = "deleting a task"
}
