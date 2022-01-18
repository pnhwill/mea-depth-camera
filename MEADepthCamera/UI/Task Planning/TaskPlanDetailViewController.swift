//
//  TaskPlanDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/17/22.
//

import UIKit
import Combine

/// A detail view controller for both viewing and editing a single Task.
class TaskPlanDetailViewController: UICollectionViewController {
    
    typealias AddCompletion = MainSplitViewController.AddCompletion
    
    private var viewModel: DetailViewModel?
    private var task: Task?
    private var isNew = false
    private var taskDidChangeSubscriber: Cancellable?
    private var addCompletion: AddCompletion?
    
    private var mainSplitViewController: MainSplitViewController {
        self.splitViewController as! MainSplitViewController
    }
    
    deinit {
        print("TaskPlanDetailViewController deinitialized.")
    }
    
    func configure(with task: Task, isNew: Bool = false, addCompletion: AddCompletion? = nil) {
        self.task = task
        self.isNew = isNew
        self.addCompletion = addCompletion
        setEditing(isNew, animated: false)
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        navigationItem.setHidesBackButton(true, animated: false)
        
        taskDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .taskDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.taskId] }
            .sink { [weak self] id in
                guard let taskId = self?.task?.id,
                      taskId == id as? UUID
                else { return }
                self?.checkValidTask()
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

extension TaskPlanDetailViewController {
    
    private func configureCollectionView() {
        guard let layout = viewModel?.createLayout() else { return }
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        viewModel?.configureDataSource(for: collectionView)
        viewModel?.applyInitialSnapshots()
    }
}

// MARK: Editing Mode Transitions
extension TaskPlanDetailViewController {
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard let task = task else { fatalError() }
        if editing {
            transitionToEditMode(task)
        } else {
            transitionToViewMode(task)
        }
        configureCollectionView()
    }
    
    private func transitionToViewMode(_ task: Task) {
        // Resign the first responder
        view.endEditing(true)
        // Save the task to persistent storage if needed
        if task.hasChanges {
            let container = AppDelegate.shared.coreDataStack.persistentContainer
            let context = task.managedObjectContext
            let contextSaveInfo: ContextSaveContextualInfo = isNew ? .addTask : .updateTask
            container.saveContext(backgroundContext: context, with: contextSaveInfo)
        }
        isNew = false
        viewModel = TaskPlanDetailViewModel(task: task)
        navigationItem.title = NSLocalizedString("View Task", comment: "view task nav title")
        navigationItem.leftBarButtonItem = nil
        editButtonItem.isEnabled = true
        addCompletion?()
    }
    
    private func transitionToEditMode(_ task: Task) {
        editButtonItem.isEnabled = false
        viewModel = TaskPlanDetailEditViewModel(task: task, isNew: isNew)
        navigationItem.title = isNew ? NSLocalizedString("Add Task", comment: "add task nav title") : NSLocalizedString("Edit Task", comment: "edit task nav title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTrigger))
    }
    
    private func checkValidTask() {
        if let name = task?.name, let fileNameLabel = task?.fileNameLabel, let instructions = task?.instructions {
            let isValid = !name.isEmpty && !fileNameLabel.isEmpty && !instructions.isEmpty
            self.editButtonItem.isEnabled = isValid
        }
    }
}

// MARK: UICollectionViewDelegate
extension TaskPlanDetailViewController {}

// MARK: Button Actions
extension TaskPlanDetailViewController {
    
    @objc
    func cancelButtonTrigger() {
        task?.managedObjectContext?.rollback()
        if isNew {
            mainSplitViewController.transitionToTaskList()
        } else {
            setEditing(false, animated: true)
        }
        addCompletion?()
    }
}
