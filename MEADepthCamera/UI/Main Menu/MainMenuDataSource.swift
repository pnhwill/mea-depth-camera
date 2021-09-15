//
//  MainMenuDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

class MainMenuDataSource: NSObject {
    typealias UseCaseChangedAction = () -> Void
    
    var useCase: UseCase? {
        didSet {
            DispatchQueue.main.async {
                self.useCaseChangedAction?()
            }
        }
    }
    private var useCaseChangedAction: UseCaseChangedAction?
    
    // Core Data provider
    lazy var dataProvider: UseCaseProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = UseCaseProvider(with: container, fetchedResultsControllerDelegate: nil)
        return provider
    }()
    
    init(useCaseChangedAction: @escaping UseCaseChangedAction) {
        self.useCaseChangedAction = useCaseChangedAction
    }
    
    // MARK: Add Use Case
    
    func add(completion: @escaping (UseCase) -> Void) {
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false) { useCase in
            completion(useCase)
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
        self.useCase = useCase
    }
}

extension MainMenuDataSource {
    func saveUseCase(_ useCase: UseCase, completion: (Bool) -> Void) {
        if let context = useCase.managedObjectContext {
            dataProvider.persistentContainer.saveContext(backgroundContext: context)
            //context.refresh(useCase, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
}
