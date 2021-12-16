//
//  TaskListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit

/// ListViewController subclass for the list of tasks associated with a single use case, which the user selects from to begin recording.
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
    
    private var mainSplitViewController: MainSplitViewController {
        self.splitViewController as! MainSplitViewController
    }
    
    deinit {
        print("TaskListViewController deinitialized.")
    }
    
    func configure(with useCase: UseCase) {
        self.useCase = useCase
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
        sectionsSubscriber = viewModel?.sectionsStore?.$allModels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshListData()
                self?.reloadHeaderData()
                self?.selectItemIfNeeded()
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Clear the collectionView selection when splitViewController is collapsed.
        clearsSelectionOnViewWillAppear = mainSplitViewController.isCollapsed
        navigationItem.setHidesBackButton(!mainSplitViewController.isCollapsed, animated: false)
        if mainSplitViewController.isCollapsed {
            mainSplitViewController.selectedItemID = nil
        }
        super.viewWillAppear(animated)
        taskListViewModel.reloadStores()
    }
}

extension TaskListViewController {
    
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
               let task = taskListViewModel.task(with: itemID),
               let useCase = useCase {
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
                mainSplitViewController.showTaskDetail(task, useCase: useCase)
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension TaskListViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the detail view when the cell is tapped.
        if let itemID = dataSource?.itemIdentifier(for: indexPath),
           let task = taskListViewModel.task(with: itemID),
           let useCase = useCase {
            mainSplitViewController.showTaskDetail(task, useCase: useCase)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}
