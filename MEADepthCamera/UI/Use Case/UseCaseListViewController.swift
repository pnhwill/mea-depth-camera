//
//  UseCaseListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import Combine

class UseCaseListViewController: ListViewController {
    
    private var useCaseListViewModel: UseCaseListViewModel {
        self.viewModel as! UseCaseListViewModel
    }
    
    private var useCaseSplitViewController: UseCaseSplitViewController {
        self.splitViewController as! UseCaseSplitViewController
    }
    
    private var useCaseDidChangeSubscriber: Cancellable?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        viewModel = UseCaseListViewModel()
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
//        selectItemIfNeeded()
        sectionsSubscriber = viewModel?.sectionsStore?.$allModels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshListData()
                self?.selectItemIfNeeded()
            }
        useCaseDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .useCaseDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.useCaseId] }
            .sink { [weak self] id in
                guard let useCaseId = id as? UUID else { return }
                self?.reconfigureItem(useCaseId)
                self?.selectItemIfNeeded()
            }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Clear the collectionView selection when splitViewController is collapsed.
        clearsSelectionOnViewWillAppear = useCaseSplitViewController.isCollapsed
        super.viewWillAppear(animated)
        if useCaseSplitViewController.isCollapsed {
            useCaseSplitViewController.selectedItemID = nil
        }
        if let navigationController = navigationController,
           navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: animated)
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = isEditing
        if !editing {
            refreshListData()
            selectItemIfNeeded()
        }
    }
    
    // MARK: Button Actions
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        addUseCase()
    }
}

// MARK: Private Methods
extension UseCaseListViewController {
    private func configureNavigationItem() {
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel as? UISearchResultsUpdating
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }
    
    private func selectItemIfNeeded() {
        guard !useCaseSplitViewController.isCollapsed else { return }
        // If something is already selected, re-select the cell in the list.
        if let selectedItemID = useCaseSplitViewController.selectedItemID,
           let indexPath = dataSource?.indexPath(for: selectedItemID) {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
        } else {
            // Select and show detail for the first list item, if any (item 0 is the header, so item 1 is the first use case in the list).
            let indexPath = IndexPath(item: 1, section: ListSection.Identifier.list.rawValue)
            if let itemID = dataSource?.itemIdentifier(for: indexPath),
               let useCase = useCaseListViewModel.useCase(with: itemID) {
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
                useCaseSplitViewController.showDetail(with: useCase)
            } else {
                // If list is empty, add a new use case.
                // TODO: fix misleading add use case screen in detail when list is empty due to search criteria
                addUseCase()
            }
        }
    }
    
    private func addUseCase() {
        useCaseListViewModel.add { [weak self] useCase in
            self?.useCaseSplitViewController.showDetail(with: useCase, isNew: true)
        }
    }
}

// MARK: ListTextCellDelegate
extension UseCaseListViewController: ListTextCellDelegate {
    
    func delete(objectFor item: ListItem) {
        useCaseListViewModel.delete(item.id) { [weak self] success in
            if success {
                self?.refreshListData() // maybe redundant?
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension UseCaseListViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the detail view when the cell is tapped.
        if let itemID = dataSource?.itemIdentifier(for: indexPath),
           let useCase = useCaseListViewModel.useCase(with: itemID) {
            useCaseSplitViewController.showDetail(with: useCase)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}



