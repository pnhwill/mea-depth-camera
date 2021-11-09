//
//  TaskListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit

class TaskListViewController: ListViewController {
    
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
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectItemIfNeeded()
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











// MARK: RecordingInteractionDelegate
//extension OldTaskListViewController: RecordingInteractionDelegate {
//    /**
//     didUpdateRecording is called as part of RecordingInteractionDelegate, or whenever a recording update requires a UI update.
//
//     Respond by updating the UI as follows.
//     - delete: reload selected row and sort the task list.
//     */
//    func didUpdateRecording(_ recording: Recording?, shouldReloadRow: Bool) {
//
//        // Get the indexPath for the recording. Use the currently selected indexPath if any, or the first row otherwise.
//        // indexPath will remain nil if the tableView has no data.
//        var indexPath: IndexPath?
//        if let _ = recording {
//            // indexPath = dataSource.index(for: recording.task)
//        } else {
//            indexPath = tableView.indexPathForSelectedRow
//            if indexPath == nil && tableView.numberOfRows(inSection: 0) > 0 {
//                indexPath = IndexPath(row: 0, section: 0)
//            }
//        }
//
//        // Update the taskListViewController: make sure the row is visible and the content is up to date.
//        if let indexPath = indexPath {
//            if shouldReloadRow {
//                tableView.reloadRows(at: [indexPath], with: .none)
//                // If we deleted a the last recording for a task, sort the tasks again and reload the whole table
//                if let task = dataSource?.task(at: indexPath.row), useCase?.recordingsCount(for: task) == 0 {
//                    dataSource?.sortTasks()
//                    tableView.reloadData()
//                }
//            }
//            tableView.scrollToRow(at: indexPath, at: .none, animated: false)
//        }
//    }
//}
