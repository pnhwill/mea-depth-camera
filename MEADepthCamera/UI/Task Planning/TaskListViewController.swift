//
//  TaskListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit
import Combine

/// ListViewController subclass for the list of tasks associated with a single use case, which the user selects from to begin recording.
class TaskListViewController: ListViewController {
    
    @IBOutlet private weak var addButton: UIBarButtonItem!
    
    private var taskListViewModel: TaskListViewModel {
        self.viewModel as! TaskListViewModel
    }
    
    private var mainSplitViewController: MainSplitViewController {
        self.splitViewController as! MainSplitViewController
    }
    
    private var taskDidChangeSubscriber: Cancellable?
    
    private var isSearching: Bool = false
    private var isAdding: Bool = false {
        didSet {
            addButton.isEnabled = !isAdding
            editButtonItem.isEnabled = !isAdding
        }
    }
    
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        viewModel = TaskListViewModel()
//    }
    
    deinit {
        print("TaskListViewController deinitialized.")
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setHidesBackButton(true, animated: false)
        viewModel = TaskListViewModel()
        configureNavigationItem()
        sectionsSubscriber = viewModel?.sectionsStore?.$allModels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshListData()
                self?.selectItemIfNeeded()
            }
        taskDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .taskDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.taskId] }
            .sink { [weak self] id in
                guard let taskId = id as? UUID else { return }
                self?.reconfigureItem(taskId)
                self?.selectItemIfNeeded()
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Clear the collectionView selection when splitViewController is collapsed.
        clearsSelectionOnViewWillAppear = mainSplitViewController.isCollapsed
//        navigationItem.setHidesBackButton(!mainSplitViewController.isCollapsed, animated: false)
//        if mainSplitViewController.isCollapsed {
//            mainSplitViewController.selectedItemID = nil
//        }
        super.viewWillAppear(animated)
//        taskListViewModel.reloadStores()
        selectItemIfNeeded()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        taskListViewModel.setDeleteMode(editing)
        collectionView.isEditing = isEditing
        refreshListData()
        if !editing {
            selectItemIfNeeded()
        }
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        addTask()
    }
}

extension TaskListViewController {
    
    private func configureNavigationItem() {
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel as? UISearchResultsUpdating
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
        navigationItem.searchController?.searchResultsUpdater = taskListViewModel
        navigationItem.searchController?.delegate = self
    }
    
    private func selectItemIfNeeded() {
        guard !mainSplitViewController.isCollapsed else { return }
        // If something is already selected, re-select the cell in the list.
        if let selectedItemID = mainSplitViewController.selectedItemID,
           let indexPath = dataSource?.indexPath(for: selectedItemID) {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
        } else {
            // Select and show detail for the first list item (we have 2 headers, so first item is at index 2).
            let indexPath = IndexPath(item: 2, section: ListSection.Identifier.list.rawValue)
            if let itemID = dataSource?.itemIdentifier(for: indexPath),
               let task = taskListViewModel.task(with: itemID) {
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
                mainSplitViewController.showTaskPlanDetail(task)
            }
        }
    }
    
    private func addTask() {
        taskListViewModel.add { [weak self] task in
            self?.isAdding = true
            self?.mainSplitViewController.showTaskPlanDetail(task, isNew: true) {
                self?.isAdding = false
            }
        }
    }
}

// MARK: ListTextCellDelegate
extension TaskListViewController: ListTextCellDelegate {
    
    func delete(objectFor item: ListItem) {
        taskListViewModel.delete(item.id) { [weak self] success in
            if success {
                self?.refreshListData() // maybe redundant?
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension TaskListViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isAdding else {
            selectItemIfNeeded()
            return
        }
        // Push the detail view when the cell is tapped.
        if let itemID = dataSource?.itemIdentifier(for: indexPath),
           let task = taskListViewModel.task(with: itemID) {
            mainSplitViewController.showTaskPlanDetail(task)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}
// MARK: UISearchControllerDelegate
extension TaskListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        isSearching = true
    }
    func didDismissSearchController(_ searchController: UISearchController) {
        isSearching = false
    }
}
