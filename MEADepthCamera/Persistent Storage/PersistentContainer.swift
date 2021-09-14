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
    
    /**
     Handles save error by presenting an alert.
     */
    private func handleSavingError(_ error: Error, contextualInfo: ContextSaveContextualInfo?) {
        print("Context saving error: \(error)")
        if let contextualInfo = contextualInfo {
            DispatchQueue.main.async {
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
    
    //    func backgroundContext() -> NSManagedObjectContext {
    //        let context = newBackgroundContext()
    //        return context
    //    }
    
}

/**
 Contextual information for handling Core Data context save errors.
 */
enum ContextSaveContextualInfo: String {
    case addUseCase = "adding a use case"
    case deleteUseCase = "deleting a use case"
    case updateUseCase = "saving use case details"
    case addRecording = "adding a recording"
    case addOutputFile = "adding an output file"
}
