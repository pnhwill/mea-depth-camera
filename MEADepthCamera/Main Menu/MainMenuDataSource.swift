//
//  MainMenuDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class MainMenuDataSource: NSObject {
    typealias CurrentUseCaseChangedAction = (UseCase?) -> Void
    
    var currentUseCase: UseCase?
    private var currentUseCaseChangedAction: CurrentUseCaseChangedAction?
    
    // Core Data persistent container
    private(set) var persistentContainer = AppDelegate.shared.coreDataStack.persistentContainer
    
    init(currentUseCaseChangedAction: @escaping CurrentUseCaseChangedAction) {
        self.currentUseCaseChangedAction = currentUseCaseChangedAction
    }
    
    // MARK: Current Use Case Configuration
    
    func updateCurrentUseCase(_ useCase: UseCase?) {
        currentUseCase = useCase
        currentUseCaseChangedAction?(currentUseCase)
    }
    
    func add(_ useCase: UseCase, completion: (Bool) -> Void) {
        saveUseCase(useCase) { id in
            let success = id != nil
            completion(success)
        }
    }
    
}

// MARK: Persistent Storage Interface

extension MainMenuDataSource {
    
    private func saveUseCase(_ useCase: UseCase, completion: (UUID?) -> Void) {
        if let context = useCase.managedObjectContext {
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(useCase, mergeChanges: true)
            completion(useCase.id)
        } else {
            completion(nil)
        }
    }
    
}

// MARK: UseCaseInteractionDelegate

extension MainMenuDataSource: UseCaseInteractionDelegate {
    /**
     didUpdateUseCase is called as part of UseCaseInteractionDelegate, or whenever a use case update requires a UI update.
     
     Respond by updating the UI as follows.
     - add: make the new item visible and select it.
     - delete: select the first item if possible.
     - update from detailViewController: reload the row, make it visible, and select it.
     - initial load: select the first item if needed.
     */
    func didUpdateUseCase(_ useCase: UseCase?, shouldReloadRow: Bool = true) {
        currentUseCase = useCase
        if shouldReloadRow {
            currentUseCaseChangedAction?(useCase)
        }
    }
}
