//
//  UseCaseDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import Combine

/// A detail view controller for both viewing and editing a single Use Case.
class UseCaseDetailViewController: UICollectionViewController {
    
    private var viewModel: DetailViewModel?
    private var useCase: UseCase?
    private var isNew = false
    private var useCaseDidChangeSubscriber: Cancellable?
    
    private var mainSplitViewController: MainSplitViewController {
        self.splitViewController as! MainSplitViewController
    }
    
    deinit {
        print("UseCaseDetailViewController deinitialized.")
    }
    
    func configure(with useCase: UseCase, isNew: Bool = false) {
        self.useCase = useCase
        self.isNew = isNew
        setEditing(isNew, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueID.showProcessingListSegueIdentifier,
           let destination = segue.destination as? UINavigationController,
           let processingListViewController = destination.topViewController as? ProcessingListViewController {
            guard let useCase = useCase else { return }
            processingListViewController.configure(useCase: useCase)
        }
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
//        if let navigationController = navigationController,
//           !navigationController.isToolbarHidden {
//            navigationController.setToolbarHidden(true, animated: animated)
//        }
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
        guard elementKind == UseCaseDetailViewModel.sectionFooterElementKind, let view = view as? ButtonSupplementaryView else { return }
        view.setButtonAction(buttonAction: startButtonTapped)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the detail view when the cell is tapped.
        if let useCase = useCase,
           let viewModel = viewModel as? UseCaseDetailViewModel,
           let itemID = viewModel.dataSource?.itemIdentifier(for: indexPath),
           let task = viewModel.task(with: itemID) {
            mainSplitViewController.showCamera(task: task, useCase: useCase)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

// MARK: Button Actions
extension UseCaseDetailViewController {
    
    @objc
    func cancelButtonTrigger() {
        useCase?.managedObjectContext?.rollback()
        if isNew {
            mainSplitViewController.transitionToUseCaseList()
        } else {
            setEditing(false, animated: true)
        }
    }
    
    private func startButtonTapped() {
        guard let useCase = useCase else { return }
        // Show the task list split view when start button is tapped
//        mainSplitViewController.transitionToTaskList(with: useCase)
    }
}

