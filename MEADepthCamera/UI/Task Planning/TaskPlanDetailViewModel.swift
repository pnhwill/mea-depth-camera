//
//  TaskPlanDetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/17/22.
//

import UIKit

/// The view model for TaskDetailViewController.
class TaskPlanDetailViewModel: DetailViewModel {
    
    // MARK: Section
    struct Section: Identifiable {
        enum Identifier: Int, CaseIterable {
            case info
        }
        
        var id: Identifier
        var items: [OldListItem.ID]
    }
    
    // MARK: Info Items
    struct InfoItems {
        enum ItemType: Int, CaseIterable {
            case name
            case fileName
            case modality
            case instructions
            
            var id: UUID {
                InfoItems.identifiers[self.rawValue]
            }
            
            var cellImage: UIImage? {
                switch self {
                case .name:
                    return nil
                case .fileName:
                    return UIImage(systemName: "folder")
                case .modality:
                    return UIImage(systemName: "video.and.waveform")
                case .instructions:
                    return UIImage(systemName: "info")
                }
            }
            
            func displayText(for task: Task) -> String? {
                switch self {
                case .name:
                    return task.name
                case .fileName:
                    return task.fileNameLabel
                case .modality:
                    return task.modality
                case .instructions:
                    return task.instructions
                }
            }
        }
        
        static let identifiers: [UUID] = {
            return ItemType.allCases.map { _ in UUID() }
        }()
    }
    
    var dataSource: UICollectionViewDiffableDataSource<Section.ID, OldListItem.ID>?
    
    // MARK: Data Stores
    lazy var sectionsStore: ObservableModelStore<Section>? = {
        let infoSection = Section(id: .info, items: infoItemIds)
        return ObservableModelStore([infoSection])
    }()
    lazy var itemsStore: ObservableModelStore<OldListItem>? = {
        let items = [infoItems].compactMap { $0 }.flatMap { $0 }
        return ObservableModelStore(items)
    }()
    
    private var task: Task
    
    private var infoItems: [OldListItem] {
        InfoItems.ItemType.allCases.map { OldListItem(id: $0.id,
                                                   title: $0.displayText(for: task) ?? "?",
                                                   image: $0.cellImage) }
    }
    private var infoItemIds: [UUID] {
        InfoItems.ItemType.allCases.map { $0.id }
    }
    
    init(task: Task) {
        self.task = task
    }
    
    // MARK: Configure Collection View
    
    func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout() { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let sectionID = Section.ID(rawValue: sectionIndex) else { return nil }
            switch sectionID {
            case .info:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .firstItemInSection
                let section = NSCollectionLayoutSection.list(using: config,
                                                             layoutEnvironment: layoutEnvironment)
                return section
            }
        }
    }
    
    func configureDataSource(for collectionView: UICollectionView) {
        
        let headerRegistration = createHeaderRegistration()
        let cellRegistration = createCellRegistration()
        
        dataSource = UICollectionViewDiffableDataSource<Section.ID, OldListItem.ID>(collectionView: collectionView) {
            (collectionView, indexPath, itemID) -> UICollectionViewCell? in
            guard let sectionID = Section.ID(rawValue: indexPath.section) else { return nil }
            
            switch sectionID {
            case .info:
                if indexPath.item == 0 {
                    return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: itemID)
                } else {
                    return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemID)
                }
            }
        }
    }
    
    func applyInitialSnapshots() {
        // Set the order for our sections
        let sections = Section.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, OldListItem.ID>()
        snapshot.appendSections(sections)
        dataSource?.apply(snapshot, animatingDifferences: false)
        
        // Set section snapshots for each section
        for sectionID in sections {
            guard let sectionSnapshot = createSnapshot(for: sectionID) else { continue }
            dataSource?.apply(sectionSnapshot, to: sectionID, animatingDifferences: false)
        }
    }
    
    private func createSnapshot(for section: Section.ID) -> NSDiffableDataSourceSectionSnapshot<OldListItem.ID>? {
        guard let items = sectionsStore?.fetchByID(section)?.items else { return nil }
        var snapshot = NSDiffableDataSourceSectionSnapshot<OldListItem.ID>()
        
        func addItems(_ itemIds: [OldListItem.ID], to parent: OldListItem.ID?) {
            snapshot.append(itemIds, to: parent)
            let menuItems = itemIds.compactMap { itemsStore?.fetchByID($0) }
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

// MARK: Cell Registration
extension TaskPlanDetailViewModel {
    
    private func createHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, OldListItem.ID> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, OldListItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.itemsStore?.fetchByID(itemID) else { return }
            var content = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            content.text = item.title
            cell.contentConfiguration = content
        }
    }
    
    private func createCellRegistration()  -> UICollectionView.CellRegistration<UICollectionViewListCell, OldListItem.ID> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, OldListItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.itemsStore?.fetchByID(itemID) else { return }
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            content.image = item.image
            cell.contentConfiguration = content
        }
    }
}
