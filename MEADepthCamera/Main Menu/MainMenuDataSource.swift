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
    private(set) lazy var persistentContainer: PersistentContainer = {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer
    }()
    
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
