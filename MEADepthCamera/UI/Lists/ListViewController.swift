//
//  ListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import UIKit
import Combine

final class ListViewController: UICollectionViewController {

    typealias ListDiffableDataSource = UICollectionViewDiffableDataSource<ListSection.ID, ListItem.ID>
    
    private var viewModel: ListViewModel?
    private var dataSource: ListDiffableDataSource?

    private var updateBindings = Set<AnyCancellable>(minimumCapacity: 4)

    private var addItemSubject = PassthroughSubject<Void, Never>()
    private var deleteItemSubject = PassthroughSubject<ListItem.ID, Never>()
    private var searchTermSubject = PassthroughSubject<String, Never>()

    private var sectionIdentifiers: [ListSection.ID] = []
    
    private var sectionStore: AnyModelStore<ListSection>?
    private var itemStore: AnyModelStore<ListItem>?
    
    private var isInitialLoad: Bool = true

    private var mainSplitViewController: MainSplitViewController? {
        return splitViewController as? MainSplitViewController
    }

    func configure(viewModel: ListViewModel) {
        self.viewModel = viewModel
        viewModel.bindToView(
            addItem: addItemSubject.eraseToAnyPublisher(),
            deleteItem: deleteItemSubject.eraseToAnyPublisher(),
            searchTerm: searchTermSubject.eraseToAnyPublisher())
        navigationItem.title = viewModel.navigationTitle
        showBarsIfNeeded()
        applyInititalBackingStore()
        if isInitialLoad {
            configureCollectionView()
            isInitialLoad = false
        }
        loadData()
        bindToViewModel()
        selectItemIfNeeded()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSearchController()
        configureToolbar()
    }

    @objc
    func addButtonAction(_ sender: UIBarButtonItem) {
        add()
    }
}

// MARK: Interactions
extension ListViewController {

    private func bindToViewModel() {
        updateBindings.removeAll(keepingCapacity: true)
        viewModel?.reloadSectionsPublisher
            .throttle(for: .seconds(0.1), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] sections in
                self?.sectionIdentifiers = sections.map { $0.id }
                self?.sectionStore?.reload(with: sections)
                self?.refreshData()
                self?.selectItemIfNeeded()
            }
            .store(in: &updateBindings)
        viewModel?.reconfigureItemPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] item in
                self?.itemStore?.merge(newModels: [item])
                self?.reconfigureItem(item.id)
            }
            .store(in: &updateBindings)
        viewModel?.addItemPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] item in
                self?.itemStore?.merge(newModels: [item])
                self?.mainSplitViewController?.showDetail(itemID: item.id, isNew: true)
            }
            .store(in: &updateBindings)
        viewModel?.deleteItemPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] itemID in
                self?.itemStore?.deleteByID(itemID)
                if let selectedItemID = self?.mainSplitViewController?.selectedItemID, itemID == selectedItemID {
                    self?.mainSplitViewController?.hideDetail()
                }
            }
            .store(in: &updateBindings)
    }

    private func applyInititalBackingStore() {
        guard let (sections, items) = viewModel?.fetchData() else { return }
        sectionIdentifiers = sections.map { $0.id }
        sectionStore = AnyModelStore(sections)
        itemStore = AnyModelStore(items)
    }

    private func selectItemIfNeeded() {
        guard let mainSplitViewController = mainSplitViewController,
              !mainSplitViewController.isCollapsed,
              let selectedItemID = mainSplitViewController.selectedItemID
        else { return }
        let indexPath = dataSource?.indexPath(for: selectedItemID)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
    }

    private func delete(_ id: ListItem.ID) {
        deleteItemSubject.send(id)
    }

    private func add() {
        addItemSubject.send()
    }
}

// MARK: Snapshots
extension ListViewController {
    typealias ListSnapshot = NSDiffableDataSourceSnapshot<ListSection.ID, ListItem.ID>

    private func loadData() {
        guard let snapshot = createSnapshot() else { return }
        dataSource?.applySnapshotUsingReloadData(snapshot)
    }

    private func refreshData() {
        guard let snapshot = createSnapshot() else { return }
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    private func createSnapshot() -> ListSnapshot? {
        // Set the order for our sections
        var snapshot = ListSnapshot()
        snapshot.appendSections(sectionIdentifiers)
        // Set section snapshots for each section
        for sectionID in sectionIdentifiers {
            guard let section = sectionStore?.fetchByID(sectionID) else { continue }
            snapshot.appendItems(section.items, toSection: sectionID)
        }
        return snapshot
    }

    private func reconfigureItem(_ itemID: ListItem.ID) {
        guard let dataSource = dataSource, dataSource.indexPath(for: itemID) != nil else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([itemID])
        dataSource.apply(snapshot)
    }
}

// MARK: Collection View
extension ListViewController {

    private func configureCollectionView() {
        collectionView.collectionViewLayout = createLayout()
        configureDataSource()
    }

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
            var configuration = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
            configuration.headerMode = .supplementary
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                return self?.trailingSwipeActionsConfiguration(for: indexPath)
            }
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            return section
        }
    }

    private func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let sectionID = dataSource?.sectionIdentifier(for: indexPath.section),
              let section = sectionStore?.fetchByID(sectionID),
              section.canDelete,
              let itemID = dataSource?.itemIdentifier(for: indexPath)
        else { return nil }
        let configuration = UISwipeActionsConfiguration(actions: [
            deleteContextualAction(itemID: itemID)
        ])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func deleteContextualAction(itemID: ListItem.ID) -> UIContextualAction {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, _ in
            self?.delete(itemID)
        }
        deleteAction.image = UIImage(systemName: "trash")
        return deleteAction
    }

    private func configureDataSource() {
        let itemCellRegistration = createListCellRegistration()
        let headerSupplementaryRegistration = createHeaderSupplementaryRegistration()

        dataSource = ListDiffableDataSource(collectionView: collectionView) {
            (collectionView, indexPath, itemID) -> UICollectionViewCell in

            return collectionView.dequeueConfiguredReusableCell(using: itemCellRegistration, for: indexPath, item: itemID)
        }

        dataSource?.supplementaryViewProvider = { (collectionView, elementKind, indexPath) in
            switch elementKind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerSupplementaryRegistration, for: indexPath)
            default:
                return nil
            }
        }
    }
}

// MARK: Cell Registrations
extension ListViewController {
    typealias ListCellRegistration = UICollectionView.CellRegistration<ListTextCell, ListItem.ID>
    typealias ListHeaderSupplementaryRegistration = UICollectionView.SupplementaryRegistration<ListHeaderSupplementaryView>
    
    private func createListCellRegistration() -> ListCellRegistration {
        return ListCellRegistration { [weak self] (cell, indexPath, itemID) in
            guard let item = self?.itemStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
    
    private func createHeaderSupplementaryRegistration() -> ListHeaderSupplementaryRegistration {
        return ListHeaderSupplementaryRegistration(elementKind: UICollectionView.elementKindSectionHeader) {
            [weak self] (supplementaryView, elementKind, indexPath) in
            guard let sectionID = self?.dataSource?.sectionIdentifier(for: indexPath.section),
                  let section = self?.sectionStore?.fetchByID(sectionID)
            else { return }
            supplementaryView.updateWithItem(ListHeaderViewModel(section))
        }
    }
}

// MARK: NavigationBar & Toolbar
extension ListViewController {
    private func configureSearchController() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationController?.isNavigationBarHidden = true
    }
    
    private func configureToolbar() {
        var flexibleSpaceBarButtonItem: UIBarButtonItem {
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                            target: nil,
                            action: nil)
        }
        let addBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonAction(_:)))
        
        let toolbarButtonItems = [
            flexibleSpaceBarButtonItem,
            addBarButtonItem,
            flexibleSpaceBarButtonItem,
        ]
        toolbarItems = toolbarButtonItems
        navigationController?.isToolbarHidden = true
    }
    
    private func showBarsIfNeeded() {
        guard let navigationController = navigationController else { return }
        if navigationController.isNavigationBarHidden {
            navigationController.setNavigationBarHidden(false, animated: true)
        }
        if navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: true)
        }
    }
}

// MARK: UICollectionViewDelegate
extension ListViewController {
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let itemID = dataSource?.itemIdentifier(for: indexPath) {
            mainSplitViewController?.showDetail(itemID: itemID)
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

// MARK: UISearchResultsUpdating
extension ListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let userInput = searchController.searchBar.text else { return }
        searchTermSubject.send(userInput)
    }
}

// MARK: UISearchControllerDelegate
//extension ListViewController: UISearchControllerDelegate {
//    func willPresentSearchController(_ searchController: UISearchController) {
////        isSearching = true
//    }
//    func didDismissSearchController(_ searchController: UISearchController) {
////        isSearching = false
//    }
//}

