//
//  ListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit
import CoreData
import Combine

/// Base class for UIViewControllers that list object data from the Core Data model and present a detail view for selected cells.
class ListViewController: UICollectionViewController {
    
    typealias Item = ListItem
    typealias Section = ListSection
    typealias ListDiffableDataSource = UICollectionViewDiffableDataSource<Section.ID, Item.ID>
    
    var viewModel: ListViewModel?
    var dataSource: ListDiffableDataSource?
    
    var sectionsSubscriber: AnyCancellable?
    
    var headerAppearance: UICollectionLayoutListConfiguration.Appearance { .insetGrouped }
    var listAppearance: UICollectionLayoutListConfiguration.Appearance { .sidebarPlain }
    
    // MARK: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        loadData()
    }
}

// MARK: Update Data
extension ListViewController {
    func loadData() {
//        guard viewModel != nil else { return }
        // Set the order for our sections
        let sections = Section.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, Item.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for sectionID in sections {
            guard let sectionSnapshot = createSnapshot(for: sectionID) else { continue }
            dataSource?.apply(sectionSnapshot, to: sectionID, animatingDifferences: false)
        }
    }
    
    func reloadHeaderData() {
        guard var snapshot = dataSource?.snapshot() else { return }
        snapshot.reloadSections([.header])
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
    
    func refreshListData() {
        guard let snapshot = createSnapshot(for: .list) else { return }
        dataSource?.apply(snapshot, to: .list)
    }
    
    func reconfigureItem(_ itemID: Item.ID) {
        guard let dataSource = dataSource, dataSource.indexPath(for: itemID) != nil else { return }
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([itemID])
        dataSource.apply(snapshot)
    }
    
    private func createSnapshot(for section: Section.ID) -> NSDiffableDataSourceSectionSnapshot<Item.ID>? {
        guard let items = viewModel?.sectionsStore?.fetchByID(section)?.items else { return nil }
        var snapshot = NSDiffableDataSourceSectionSnapshot<Item.ID>()
        
        func addItems(_ itemIds: [ListItem.ID], to parent: ListItem.ID?) {
            snapshot.append(itemIds, to: parent)
            let menuItems = itemIds.compactMap { viewModel?.itemsStore?.fetchByID($0) }
            for menuItem in menuItems where !menuItem.subItems.isEmpty {
                let subItemIds = menuItem.subItems.map { $0.id }
                addItems(subItemIds, to: menuItem.id)
            }
        }
        
        addItems(items, to: nil)
        snapshot.expand(items)
        return snapshot
    }
}

// MARK: Collection View Configuration
extension ListViewController {
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView.collectionViewLayout = layout
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { [unowned self]
            (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let sectionID = Section.ID(rawValue: sectionIndex) else { return nil }
            let section: NSCollectionLayoutSection
            switch sectionID {
            case .header:
                var configuration = UICollectionLayoutListConfiguration(appearance: self.headerAppearance)
                configuration.headerMode = .firstItemInSection
                section = NSCollectionLayoutSection.list(using: configuration,
                                                         layoutEnvironment: layoutEnvironment)
            case .list:
                var configuration = UICollectionLayoutListConfiguration(appearance: self.listAppearance)
                configuration.headerMode = .firstItemInSection
                configuration.headerTopPadding = 0
                section = NSCollectionLayoutSection.list(using: configuration,
                                                         layoutEnvironment: layoutEnvironment)
            }
            return section
        }
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
//        configuration.interSectionSpacing = 20
        return UICollectionViewCompositionalLayout(sectionProvider: sectionProvider,
                                                   configuration: configuration)
    }
    
    private func configureDataSource() {
        let headerCellRegistration = createHeaderCellRegistration()
        let listCellRegistration = createListCellRegistration()
        let containerCellRegistration = createContainerCellRegistration()
        let sectionHeaderCellRegistration = createSectionHeaderCellRegistration()
        
        dataSource = ListDiffableDataSource(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, itemID) -> UICollectionViewCell? in
            guard let sectionID = Section.ID(rawValue: indexPath.section) else { return nil }
            
            if indexPath.item == 0 {
                return collectionView.dequeueConfiguredReusableCell(using: sectionHeaderCellRegistration, for: indexPath, item: itemID)
            } else {
                guard let item = self?.viewModel?.itemsStore?.fetchByID(itemID) else { return nil }
                if item.subItems.isEmpty {
                    switch sectionID {
                    case .header:
                        return collectionView.dequeueConfiguredReusableCell(using: headerCellRegistration, for: indexPath, item: itemID)
                    case .list:
                        return collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: itemID)
                    }
                } else {
                    return collectionView.dequeueConfiguredReusableCell(using: containerCellRegistration, for: indexPath, item: itemID)
                }
            }
        }
    }
    
    // MARK: Cell Registration
    
    private func createListCellRegistration() -> UICollectionView.CellRegistration<ListTextCell, Item.ID> {
        return UICollectionView.CellRegistration<ListTextCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
            cell.delegate = self as? ListTextCellDelegate
        }
    }
    
    private func createContainerCellRegistration() -> UICollectionView.CellRegistration<ExpandableHeaderCell, Item.ID> {
        return UICollectionView.CellRegistration<ExpandableHeaderCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
    
    private func createHeaderCellRegistration() -> UICollectionView.CellRegistration<HeaderTextCell, Item.ID> {
        return UICollectionView.CellRegistration<HeaderTextCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
    
    private func createSectionHeaderCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> { [weak self] (cell, indexPath, itemID) in
            guard let item = self?.viewModel?.itemsStore?.fetchByID(itemID) else { return }
            var contentConfiguration = UIListContentConfiguration.sidebarHeader()
            contentConfiguration.text = item.title
            cell.contentConfiguration = contentConfiguration
        }
    }
}

