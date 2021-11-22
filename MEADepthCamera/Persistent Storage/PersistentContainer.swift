//
//  PersistentContainer.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import CoreData

class PersistentContainer: NSPersistentContainer {
    
    // MARK: Core Data Saving support
    
    /**
     Save a context, or handle the save error (for example, when there data inconsistency or low memory).
     */
    func saveContext(backgroundContext: NSManagedObjectContext? = nil, with contextualInfo: ContextSaveContextualInfo? = nil) {
        let context = backgroundContext ?? viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            handleSavingError(error, contextualInfo: contextualInfo)
        }
    }
    
//    func backgroundContext() -> NSManagedObjectContext {
//        let context = newBackgroundContext()
//        return context
//    }
    
    /**
     Handles save error by presenting an alert.
     */
    private func handleSavingError(_ error: Error, contextualInfo: ContextSaveContextualInfo?) {
        print("Context saving error: \(error)")
        if let contextualInfo = contextualInfo {
            DispatchQueue.main.async {
                // TODO: this guard always fails. access window via the uiwindowscene like below
                //        guard let mainWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { fatalError("no window scene") }
                //        guard let window = mainWindowScene.windows.first else { fatalError("no window") }
                //        guard let rootNavController = window.rootViewController as? UINavigationController else { fatalError("no root nav controller") }
                guard let window = UIApplication.shared.delegate?.window,
                      let viewController = window?.rootViewController else { return }
                
                let message = "Failed to save the context when \(contextualInfo.rawValue)."
                
                // Append message to existing alert if present
                if let currentAlert = viewController.presentedViewController as? UIAlertController {
                    currentAlert.message = (currentAlert.message ?? "") + "\n\n\(message)"
                    return
                }
                
                // Otherwise present a new alert
                viewController.alert(title: "Core Data Saving Error", message: message, actions: [UIAlertAction(title: "OK", style: .default)])
            }
        }
    }
}

/**
 Contextual information for handling Core Data context save errors.
 */
enum ContextSaveContextualInfo: String {
    case addUseCase = "adding a use case"
    case deleteUseCase = "deleting a use case"
    case updateUseCase = "saving use case details"
    case addRecording = "adding a recording"
    case updateRecording = "saving recording details"
    case deleteRecording = "deleting a recording"
    case addOutputFile = "adding an output file"
    case deleteOutputFile = "deleting an output file"
    case addExperiment = "adding an experiment"
    case deleteExperiment = "deleting an experiment"
    case addTask = "adding a task"
    case deleteTask = "deleting a task"
}
