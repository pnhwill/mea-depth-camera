//
//  TaskDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/17/22.
//

import UIKit
import Combine

/// A detail view controller for both viewing and editing a single Task.
final class TaskDetailViewController: UICollectionViewController, DetailViewController {
    
    private var viewModel: DetailViewModel?
    private var task: Task?
    private var isNew = false
    private var isHidden: Bool = true
    
    private var isInputValid: Cancellable?
    
    // MARK: DetailViewController
    
    func configure(with taskID: UUID, isNew: Bool) {
        guard let task = TaskProvider.fetchObject(with: taskID) else { return }
        self.task = task
        self.isNew = isNew
        navigationController?.setNavigationBarHidden(false, animated: true)
        isHidden = false
        setEditing(isNew, animated: false)
        
        isInputValid = task.publisher(for: \.name)
            .combineLatest(task.publisher(for: \.fileNameLabel), task.publisher(for: \.instructions))
            .receive(on: RunLoop.main)
            .sink { [weak self] (name, fileNameLabel, instructions) in
                guard let editViewModel = self?.viewModel as? TaskDetailEditViewModel else { return }
                self?.editButtonItem.isEnabled = editViewModel.validateInput(
                    name: name,
                    fileNameLabel: fileNameLabel,
                    instructions: instructions)
            }
    }
    
    func hide() {
        guard !isHidden else { return }
        task = nil
        collectionView.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        isHidden = true
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setRightBarButton(editButtonItem, animated: false)
    }
}

// MARK: Configure Collection View

extension TaskDetailViewController {
    
    private func configureCollectionView() {
        guard let layout = viewModel?.createLayout() else { return }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        viewModel?.configureDataSource(for: collectionView)
        viewModel?.applyInitialSnapshots()
    }
}

// MARK: Editing Mode Transitions
extension TaskDetailViewController {
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard let task = task else { fatalError() }
        if editing {
            transitionToEditMode(task)
        } else {
            transitionToViewMode(task)
        }
        navigationItem.title = viewModel?.navigationTitle
        configureCollectionView()
    }
    
    private func transitionToViewMode(_ task: Task) {
        // Resign the first responder
        view.endEditing(true)
        // Save the task to persistent storage if needed
        saveIfNeeded()
        isNew = false
        viewModel = TaskDetailViewModel(task: task)
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = !task.isDefault
    }
    
    private func transitionToEditMode(_ task: Task) {
        editButtonItem.isEnabled = false
        viewModel = TaskDetailEditViewModel(task: task, isNew: isNew)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTrigger))
    }
}

// MARK: Button Actions
extension TaskDetailViewController {
    
    @objc
    func cancelButtonTrigger() {
        task?.managedObjectContext?.rollback()
        setEditing(false, animated: true)
    }
    
    private func saveIfNeeded() {
        if let task = task, task.hasChanges, let editViewModel = viewModel as? TaskDetailEditViewModel {
            editViewModel.save() { success in
                if !success {
                    task.managedObjectContext?.rollback()
                }
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension TaskDetailViewController {}
