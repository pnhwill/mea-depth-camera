//
//  UseCaseDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import Combine

class UseCaseDetailViewController: UICollectionViewController {
    
    private static let mainStoryboardName = "Main"
    private static let taskNavControllerIdentifier = "TaskNavViewController"
    
    private var viewModel: DetailViewModel?
    private var useCase: UseCase?
    private var isNew = false
    private var useCaseDidChangeSubscriber: Cancellable?
    
    func configure(with useCase: UseCase, isNew: Bool = false) {
        self.useCase = useCase
        self.isNew = isNew
        setEditing(isNew, animated: false)
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        
        useCaseDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .useCaseDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.useCaseId] }
            .sink { [weak self] id in
                guard let useCaseId = self?.useCase?.id,
                      useCaseId == id as? UUID
                else { return }
                self?.checkValidUseCase()
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let navigationController = navigationController,
           !navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(true, animated: animated)
        }
    }
}

// MARK: Configure Collection View

extension UseCaseDetailViewController {
    
    private func configureCollectionView() {
        guard let layout = viewModel?.createLayout() else { return }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        viewModel?.configureDataSource(for: collectionView)
        viewModel?.applyInitialSnapshots()
    }
}

// MARK: Editing Mode Transitions
extension UseCaseDetailViewController {
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard let useCase = useCase else { fatalError() }
        if editing {
            transitionToEditMode(useCase)
        } else {
            transitionToViewMode(useCase)
        }
        configureCollectionView()
    }
    
    private func transitionToViewMode(_ useCase: UseCase) {
        // Resign the first responder
        view.endEditing(true)
        // Save the use case to persistent storage if needed
        if useCase.hasChanges {
            let container = AppDelegate.shared.coreDataStack.persistentContainer
            let context = useCase.managedObjectContext
            let contextSaveInfo: ContextSaveContextualInfo = isNew ? .addUseCase : .updateUseCase
            container.saveContext(backgroundContext: context, with: contextSaveInfo)
        }
        isNew = false
        viewModel = UseCaseDetailViewModel(useCase: useCase)
        navigationItem.title = NSLocalizedString("View Use Case", comment: "view use case nav title")
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = true
    }
    
    private func transitionToEditMode(_ useCase: UseCase) {
        editButtonItem.isEnabled = false
        viewModel = UseCaseDetailEditViewModel(useCase: useCase, isNew: isNew)
        navigationItem.title = isNew ? NSLocalizedString("Add Use Case", comment: "add use case nav title") : NSLocalizedString("Edit Use Case", comment: "edit use case nav title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTrigger))
    }
    
    private func checkValidUseCase() {
        if let title = useCase?.title, let subjectID = useCase?.subjectID {
            let isValid = !title.isEmpty && !subjectID.isEmpty
            self.editButtonItem.isEnabled = isValid
        }
    }
}

// MARK: UICollectionViewDelegate
extension UseCaseDetailViewController {
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        guard elementKind == UseCaseDetailViewModel.sectionFooterElementKind, let view = view as? StartButtonSupplementaryView else { return }
        view.setButtonAction(startButtonAction: showTaskList)
    }
}

// MARK: Button Actions
extension UseCaseDetailViewController {
    
    @objc
    func cancelButtonTrigger() {
        useCase?.managedObjectContext?.rollback()
        if isNew {
            // TODO: only call this if necessary
            navigationController?.popToRootViewController(animated: true)
        } else {
            setEditing(false, animated: true)
        }
    }
    
    private func showTaskList() {
        guard let useCase = useCase else { return }
        // Show the task list split view when start button is tapped
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        guard let taskNavController = storyboard.instantiateViewController(withIdentifier: Self.taskNavControllerIdentifier) as? UINavigationController,
              let taskSplitVC = taskNavController.topViewController as? TaskSplitViewController
        else { return }
        taskSplitVC.configure(with: useCase)
        show(taskNavController, sender: nil)
//        guard let mainWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { fatalError("no window scene") }
//        guard let window = mainWindowScene.windows.first else { fatalError("no window") }
//        window.rootViewController = taskSplitVC
    }
}

