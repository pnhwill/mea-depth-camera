//
//  UseCaseListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import Combine

/// OldListViewController subclass that displays all of the user's Tasks.
class UseCaseListViewController: OldListViewController {
    
    @IBOutlet private weak var addButton: UIBarButtonItem!
    
    private var useCaseListViewModel: OldUseCaseListViewModel? {
        get {
            viewModel as? OldUseCaseListViewModel
        }
        set {
            viewModel = newValue
            sectionsSubscriber = viewModel?.sectionsStore?.$allModels
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.refreshListData()
                    self?.selectItemIfNeeded()
                }
        }
    }
    
    private var mainSplitViewController: OldMainSplitViewController {
        self.splitViewController as! OldMainSplitViewController
    }
    
    private var useCaseDidChangeSubscriber: Cancellable?
    private var coreDataStackSubscriber: AnyCancellable?
    
    private var isSearching: Bool = false
    private var isAdding: Bool = false {
        didSet {
            addButton.isEnabled = !isAdding
            editButtonItem.isEnabled = !isAdding
        }
    }
    
    deinit {
        print("UseCaseListViewController deinitialized.")
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        func setUpAndLoad() {
            useCaseListViewModel = OldUseCaseListViewModel()
            navigationItem.searchController?.searchResultsUpdater = useCaseListViewModel
            navigationItem.searchController?.delegate = self
            loadData()
        }
        let coreDataStack = AppDelegate.shared.coreDataStack
        if coreDataStack.isLoaded {
            setUpAndLoad()
        } else {
            coreDataStackSubscriber = AppDelegate.shared.coreDataStack.$isLoaded
                .receive(on: RunLoop.main)
                .sink { isLoaded in
                    if isLoaded {
                        setUpAndLoad()
                    }
                }
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
        clearsSelectionOnViewWillAppear = mainSplitViewController.isCollapsed
        super.viewWillAppear(animated)
//        if mainSplitViewController.isCollapsed {
//            mainSplitViewController.selectedItemID = nil
//        }
        selectItemIfNeeded()
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
//        debugPrint(#function)
        guard !mainSplitViewController.isCollapsed else { return }
        // If something is already selected, re-select the cell in the list.
        if let selectedItemID = mainSplitViewController.selectedItemID,
           let indexPath = dataSource?.indexPath(for: selectedItemID) {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
        } else {
            // Select and show detail for the first list item, if any (item 0 is the header, so item 1 is the first use case in the list).
            let indexPath = IndexPath(item: 1, section: OldListSection.Identifier.list.rawValue)
            if let itemID = dataSource?.itemIdentifier(for: indexPath),
               let useCase = useCaseListViewModel?.useCase(with: itemID) {
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
                mainSplitViewController.showUseCaseDetail(useCase)
            } else {
                // If list is empty, add a new use case.
                if !isSearching {
                    addUseCase()
                }
            }
        }
    }
    
    private func addUseCase() {
        useCaseListViewModel?.add { [weak self] useCase in
            self?.isAdding = true
            self?.mainSplitViewController.showUseCaseDetail(useCase, isNew: true) {
                self?.isAdding = false
            }
        }
    }
}

// MARK: ListTextCellDelegate
extension UseCaseListViewController: ListTextCellDelegate {
    
    func delete(objectFor item: OldListItem) {
        useCaseListViewModel?.delete(item.id) { [weak self] success in
            if success {
                self?.refreshListData() // maybe redundant?
            }
        }
    }
}

// MARK: UICollectionViewDelegate
extension UseCaseListViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isAdding else {
            selectItemIfNeeded()
            return
        }
        // Push the detail view when the cell is tapped.
        if let itemID = dataSource?.itemIdentifier(for: indexPath),
           let useCase = useCaseListViewModel?.useCase(with: itemID) {
            mainSplitViewController.showUseCaseDetail(useCase)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

// MARK: UISearchControllerDelegate
extension UseCaseListViewController: UISearchControllerDelegate {
    
    func willPresentSearchController(_ searchController: UISearchController) {
        isSearching = true
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        isSearching = false
    }
}

// MARK: UISplitViewControllerDelegate
extension UseCaseListViewController: UISplitViewControllerDelegate {
    
}
