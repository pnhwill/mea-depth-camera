//
//  TaskListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit

class TaskListViewController: ListViewController {
    
    private static let showRecordingListSegueIdentifier = "ShowRecordingListSegue"
    
    private var useCase: UseCase? {
        didSet {
            if let useCase = useCase {
                viewModel = TaskListViewModel(useCase: useCase)
            }
        }
    }
    
    private var taskListViewModel: TaskListViewModel {
        self.viewModel as! TaskListViewModel
    }
    
    private var taskSplitViewController: TaskSplitViewController {
        self.splitViewController as! TaskSplitViewController
    }
    
    func configure(with useCase: UseCase) {
        self.useCase = useCase
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showRecordingListSegueIdentifier,
           let destination = segue.destination as? UINavigationController,
           let recordingListViewController = destination.topViewController as? RecordingListViewController {
            guard let useCase = useCase else { return }
            recordingListViewController.configure(useCase: useCase)
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        listItemsSubscriber = viewModel?.sectionsStore?.$allModels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshListData()
                self?.selectItemIfNeeded()
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Clear the collectionView selection when splitViewController is collapsed.
        clearsSelectionOnViewWillAppear = taskSplitViewController.isCollapsed
        super.viewWillAppear(animated)
        taskListViewModel.reloadStores()
    }
    
    // MARK: Button Actions
    
    @IBAction func processButtonTapped(_ sender: UIBarButtonItem) {
        print(#function)
    }
}

extension TaskListViewController {
    
    private func selectItemIfNeeded() {
        guard !taskSplitViewController.isCollapsed else { return }
        // If something is already selected, re-select the cell in the list.
        if let selectedItemID = taskSplitViewController.selectedItemID,
           let indexPath = dataSource?.indexPath(for: selectedItemID) {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
        } else {
            // Select and show detail for the first list item (we have 2 headers, so first item is at index 2).
            let indexPath = IndexPath(item: 2, section: ListSection.Identifier.list.rawValue)
            if let itemID = dataSource?.itemIdentifier(for: indexPath),
               let task = taskListViewModel.task(with: itemID) {
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
                taskSplitViewController.showDetail(with: task)
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension TaskListViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the detail view when the cell is tapped.
        if let itemID = dataSource?.itemIdentifier(for: indexPath),
           let task = taskListViewModel.task(with: itemID) {
            taskSplitViewController.showDetail(with: task)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}
