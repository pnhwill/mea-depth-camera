//
//  UseCaseListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit

class UseCaseListViewController: ListViewController {
    
    private var useCaseListViewModel: UseCaseListViewModel? {
        viewModel as? UseCaseListViewModel
    }
    
    private var useCaseSplitViewController: UseCaseSplitViewController? {
        splitViewController as? UseCaseSplitViewController
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        viewModel = UseCaseListViewModel()
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        allItemsSubscriber = viewModel.itemsStore?.$allModels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshListData()
                self?.selectItemIfNeeded()
            }
    }
    
    /**
     Clear the tableView selection when splitViewController is collapsed.
     */
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
        selectItemIfNeeded()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = isEditing
    }
    
    // MARK: Button Actions
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        addUseCase()
    }
}

extension UseCaseListViewController {
    private func configureNavigationItem() {
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel as? UISearchResultsUpdating
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
    }
    
    private func selectItemIfNeeded() {
        var indexPath: IndexPath?
        if let selectedItemID = useCaseSplitViewController?.selectedItemID {
            indexPath = dataSource?.indexPath(for: selectedItemID)
        } else {
            if !splitViewController!.isCollapsed {
                indexPath = IndexPath(item: 0, section: ListSection.Identifier.list.rawValue)
            }
        }
        if let indexPath = indexPath {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
        } else {
            addUseCase()
        }
    }
    
    private func addUseCase() {
        useCaseListViewModel?.add { [weak self] useCase in
            self?.useCaseSplitViewController?.configureDetail(with: useCase, isNew: true)
        }
    }
}

// MARK: UICollectionViewDelegate
extension UseCaseListViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the detail view when the cell is tapped.
        if let itemID = dataSource?.itemIdentifier(for: indexPath),
           let item = viewModel.itemsStore?.fetchByID(itemID),
           let useCase = item.object as? UseCase {
            useCaseSplitViewController?.configureDetail(with: useCase)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

// MARK: UseCaseInteractionDelegate
extension UseCaseListViewController: UseCaseInteractionDelegate {
    /**
     didUpdateUseCase is called as part of UseCaseInteractionDelegate, or whenever a use case update requires a UI update (including main-detail selections).
     
     Respond by updating the UI as follows.
     - add:
     - delete: reload snapshot and apply to collection view data source
     - update from detailViewController:
     - initial load:
     */
    func didUpdateUseCase(_ useCase: UseCase) {
        guard let itemID = useCase.id else { fatalError() }
        itemDidChange(itemID)
    }
}

// MARK: ListTextCellDelegate
extension UseCaseListViewController: ListTextCellDelegate {
    
    func contentConfiguration(for item: ListItem) -> TextCellContentConfiguration? {
        guard let useCase = item.object as? UseCase else { fatalError() }
        let titleText = useCase.title ?? ""
        let experimentText = useCase.experimentTitle
        let dateText = useCase.dateTimeText(for: .all) ?? ""
        let subjectID = useCase.subjectID ?? ""
        let subjectIDText = "Subject ID: " + subjectID
        let completedTasksText = "X out of X tasks completed"
        let bodyText = [subjectIDText, dateText, completedTasksText]
        let content = TextCellContentConfiguration(titleText: titleText, subtitleText: experimentText, bodyText: bodyText)
        return content
    }
    
    func delete(objectFor item: ListItem) {
        guard let useCase = item.object as? UseCase else { fatalError() }
        useCaseListViewModel?.delete(useCase) { [weak self] success in
            if success {
                self?.useCaseSplitViewController?.selectedItemID = nil
                self?.selectItemIfNeeded()
            }
        }
    }
}




class SecondUseCaseListViewController: OldListViewController<OldUseCaseListViewModel> {
    
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "UseCaseDetailViewController"
    
    var addButton: UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SecondUseCaseListViewController.addUseCase(_:)))
    }
    
    init() {
        super.init(viewModel: OldUseCaseListViewModel())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        collectionView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
           navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: animated)
        }
        setToolbarItems([addButton], animated: animated)
    }
    
    // MARK: Button Actions
    @objc
    func addUseCase(_ sender: UIBarButtonItem) {
        viewModel.add() { [weak self] useCase in
//            let detailViewController = UseCaseDetailViewController(useCase: useCase, isNew: true)
//            detailViewController.delegate = self?.viewModel
//            self?.show(detailViewController, sender: self)
        }
        
        
//        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
//        let detailViewController: OldUseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
//        viewModel.add() { useCase in
//            DispatchQueue.main.async {
//                detailViewController.configure(with: useCase, isNew: true, addAction: { useCase in
//                    self.viewModel.update(useCase) { success in
//                        if success, let dataSource = self.viewModel.dataSource, let itemID = useCase.id {
//                            var snapshot = dataSource.snapshot()
//                            snapshot.appendItems([itemID], toSection: .list)
//                            dataSource.apply(snapshot)
//                        }
//                    }
//                })
//            }
//        }
//        let navigationController = UINavigationController(rootViewController: detailViewController)
//        present(navigationController, animated: true, completion: nil)
    }
    
}

extension SecondUseCaseListViewController {
    private func configureNavigationItem() {
        navigationItem.setRightBarButton(editButtonItem, animated: false)
        // Search bar controller
//        let searchController = UISearchController(searchResultsController: nil)
//        searchController.searchResultsUpdater = viewModel
//        searchController.obscuresBackgroundDuringPresentation = false
//        navigationItem.searchController = searchController
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.isEditing = isEditing
    }
}

// MARK: UICollectionViewDelegate
extension SecondUseCaseListViewController: UICollectionViewDelegate {
    
//    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
//        guard let cell = cell as? UseCaseListCell else { fatalError() }
//        cell.delegate = viewModel
//    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Push the detail view when the cell is tapped.
        guard let itemID = viewModel.dataSource?.itemIdentifier(for: indexPath),
              let item = viewModel.itemsStore?.fetchByID(itemID),
              let useCase = item.object as? UseCase
        else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
//        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
//        let detailViewController: OldUseCaseDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
//        detailViewController.configure(with: useCase, editAction: { useCase in
//            self.viewModel.update(useCase) { success in
//                if success, let dataSource = self.viewModel.dataSource {
//                    var snapshot = dataSource.snapshot()
//                    snapshot.reloadItems([itemID])
//                    dataSource.apply(snapshot)
//                }
//            }
//        })
//        let detailViewController = UseCaseDetailViewController(useCase: useCase)
//        detailViewController.delegate = viewModel
//        show(detailViewController, sender: self)
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

