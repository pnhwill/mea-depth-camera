//
//  UseCaseDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit
import Combine

/// A detail view controller for both viewing and editing a single Use Case.
final class UseCaseDetailViewController: UICollectionViewController, DetailViewController {
    
    private var viewModel: DetailViewModel?
    private var useCase: UseCase?
    private var isNew: Bool = false
    private var isHidden: Bool = true
    
    private var isInputValid: Cancellable?
    
    private var mainSplitViewController: MainSplitViewController? {
        return splitViewController as? MainSplitViewController
    }
    
    deinit {
        print("UseCaseDetailViewController deinitialized.")
    }
    
    // MARK: DetailViewController
    
    func configure(with useCaseID: UUID, isNew: Bool) {
        guard let useCase = UseCaseProvider.fetchObject(with: useCaseID) else { return }
        self.useCase = useCase
        self.isNew = isNew
        navigationController?.setNavigationBarHidden(false, animated: true)
        isHidden = false
        setEditing(isNew, animated: false)
        
        isInputValid = useCase.publisher(for: \.title)
            .combineLatest(useCase.publisher(for: \.subjectID))
            .receive(on: RunLoop.main)
            .sink { [weak self] (title, subjectID) in
                guard let editViewModel = self?.viewModel as? UseCaseDetailEditViewModel else { return }
                self?.editButtonItem.isEnabled = editViewModel.validateInput(
                    title: title,
                    subjectID: subjectID)
            }
    }
    
    func hide() {
        guard !isHidden else { return }
        useCase = nil
        collectionView.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        isHidden = true
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
        navigationItem.title = viewModel?.navigationTitle
        configureCollectionView()
    }
    
    private func transitionToViewMode(_ useCase: UseCase) {
        // Resign the first responder
        view.endEditing(true)
        saveIfNeeded()
        isNew = false
        viewModel = UseCaseDetailViewModel(useCase: useCase)
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = true
    }
    
    private func transitionToEditMode(_ useCase: UseCase) {
        editButtonItem.isEnabled = false
        viewModel = UseCaseDetailEditViewModel(useCase: useCase, isNew: isNew)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTrigger))
    }
}

// MARK: Button Actions
extension UseCaseDetailViewController {
    
    @objc
    func cancelButtonTrigger() {
        useCase?.managedObjectContext?.rollback()
        setEditing(false, animated: true)
    }
    
    /// Saves the `UseCase` to persistent storage if it has changes.
    private func saveIfNeeded() {
        if let useCase = useCase, useCase.hasChanges, let editViewModel = viewModel as? UseCaseDetailEditViewModel {
            editViewModel.save() { success in
                if !success {
                    useCase.managedObjectContext?.rollback()
                }
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension UseCaseDetailViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the camera view when the cell is tapped.
        if let useCase = useCase,
           let viewModel = viewModel as? UseCaseDetailViewModel,
           let itemID = viewModel.itemID(at: indexPath),
           let task = TaskProvider.fetchObject(with: itemID) {
            mainSplitViewController?.showCamera(task: task, useCase: useCase)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}
