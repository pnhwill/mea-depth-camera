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
        selectItemIfNeeded()
        listItemsSubscriber = viewModel.sectionsStore?.$allModels
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
            // Select and show detail for the first list item, if any.
            let indexPath = IndexPath(item: 0, section: ListSection.Identifier.list.rawValue)
            if let itemID = dataSource?.itemIdentifier(for: indexPath),
               let useCase = useCaseListViewModel.useCase(with: itemID) {
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
                useCaseSplitViewController.showDetail(with: useCase)
            } else {
                // If list is empty, add a new use case.
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

// MARK: ListTextCellDelegate
extension UseCaseListViewController: ListTextCellDelegate {
    
    func delete(objectFor item: ListItem) {
        useCaseListViewModel.delete(item.id) { [weak self] success in
            if success {
                self?.refreshListData()
            }
        }
    }
}













// MARK: - OldUseCaseListViewController
class OldUseCaseListViewController: UITableViewController {

    @IBOutlet var filterSegmentedControl: UISegmentedControl!

    static let mainStoryboardName = "Main"
    static let unwindFromListSegueIdentifier = "UnwindFromUseCaseListSegue"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"

    private var dataSource: UseCaseListDataSource?
    private var filter: UseCaseListViewModel.Filter {
        return UseCaseListViewModel.Filter(rawValue: filterSegmentedControl.selectedSegmentIndex) ?? .today
    }

    //weak var delegate: UseCaseInteractionDelegate?
    private var currentUseCaseID: UUID?

    // MARK: Navigation
    func configure(with useCase: UseCase?) {
        currentUseCaseID = useCase?.id
        dataSource = UseCaseListDataSource(useCaseDeletedAction: { deletedUseCaseID in
            if deletedUseCaseID == self.currentUseCaseID {
                self.currentUseCaseID = nil
            }
        }, useCaseChangedAction: {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        })
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.unwindFromListSegueIdentifier,
           let cell = sender as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            // Return to main menu with selected use case as current use case
            let rowIndex = indexPath.row
            guard let useCase = dataSource?.useCase(at: rowIndex) else {
                fatalError("Couldn't find data source for use case list.")
            }
            currentUseCaseID = useCase.id
        }
    }

    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = dataSource
        navigationItem.title = dataSource?.navigationTitle
        // Search bar controller
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = dataSource
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
           navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: animated)
        }
    }

    // MARK: Actions

    @IBAction func addButtonTriggered(_ sender: UIBarButtonItem) {
        addUseCase()
    }

    @IBAction func segmentControlChanged(_ sender: UISegmentedControl) {
        dataSource?.filter = filter
        tableView.reloadData()
    }

    private func addUseCase() {
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: OldUseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        dataSource?.add() { useCase in
            detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
                self.dataSource?.update(useCase) { success in
                    if success {
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }
                }
            })
        }
        let navigationController = UINavigationController(rootViewController: detailViewController)
        present(navigationController, animated: true, completion: nil)
    }
}

// MARK: UITableViewDelegate
extension OldUseCaseListViewController {
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // Push the detail view when the info button is pressed.
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: OldUseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)

        let rowIndex = indexPath.row
        guard let useCase = dataSource?.useCase(at: rowIndex) else {
            fatalError("Couldn't find data source for use case list.")
        }

        detailViewController.configure(with: useCase, editAction: { useCase in
            self.dataSource?.update(useCase) { success in
                if success {
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                } else {
                    DispatchQueue.main.async {
                        let alertTitle = NSLocalizedString("Can't Update Use Case", comment: "error updating use case title")
                        let alertMessage = NSLocalizedString("An error occured while attempting to update the use case.", comment: "error updating use case message")
                        let actionTitle = NSLocalizedString("OK", comment: "ok action title")
                        let actions = [UIAlertAction(title: actionTitle, style: .default, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        })]
                        self.alert(title: alertTitle, message: alertMessage, actions: actions)
                    }
                }
            }
        })
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

// MARK: UINavigationControllerDelegate

extension OldUseCaseListViewController: UINavigationControllerDelegate {
    //TODO: replace this with UseCaseInteractionDelegate methods
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
//        if let mainMenuViewController = viewController as? MainMenuViewController {
//            mainMenuViewController.configure(with: dataSource?.useCase(with: currentUseCaseID))
//        }
    }
}

