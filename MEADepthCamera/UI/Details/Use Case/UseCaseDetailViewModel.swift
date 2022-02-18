//
//  UseCaseDetailViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 8/10/21.
//

import UIKit

/// The view model for UseCaseDetailViewController when it is in view mode.
class UseCaseDetailViewModel: DetailViewModel {
    
    // MARK: Section
    struct Section: Identifiable {
        enum Identifier: Int, CaseIterable {
            case info
            case tasks
        }
        
        var id: Identifier
        var items: [DetailItem.ID]
    }
    
    // MARK: UseCaseItem
    enum UseCaseItem: Int, CaseIterable, DictionaryIdentifiable {
        case title
        case experiment
        case subjectID
        case date
        case completedTasks
        case notes
        
        static let identifiers = newIdentifierDictionary()
        
        static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()
        
        static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.timeStyle = .none
            formatter.dateStyle = .long
            return formatter
        }()
        
        var cellImage: UIImage? {
            switch self {
            case .title:
                return nil
            case .experiment:
                return UIImage(systemName: "chart.bar.xaxis")
            case .date:
                return UIImage(systemName: "calendar")
            case .subjectID:
                return UIImage(systemName: "person.fill.viewfinder")
            case .completedTasks:
                return UIImage(systemName: "checklist")
            case .notes:
                return UIImage(systemName: "square.and.pencil")
            }
        }
        
        func displayText(for useCase: UseCase) -> String? {
            switch self {
            case .title:
                return useCase.title
            case .experiment:
                return useCase.experimentTitle ?? useCase.experiment?.title
            case .date:
                guard let date = useCase.date else { return nil }
                let timeText = Self.timeFormatter.string(from: date)
                if Locale.current.calendar.isDateInToday(date) {
                    return UseCase.todayDateFormatter.string(from: date)
                }
                return Self.dateFormatter.string(from: date) + " at " + timeText
            case .subjectID:
                guard let subjectID = useCase.subjectID else { return nil }
                return "Subject ID: " + subjectID
            case .completedTasks:
                return "\(useCase.completedTasks) out of \(useCase.tasksCount) tasks completed"
            case .notes:
                return useCase.notes
            }
        }
        
        static func listItems(for useCase: UseCase) -> [DetailItem] {
            Self.allCases.map { DetailItem(id: $0.id, title: $0.displayText(for: useCase) ?? "", image: $0.cellImage) }
        }
    }
    
    // MARK: TaskHeaders
    private struct TaskHeaders {
        enum HeaderType: Int, CaseIterable, DictionaryIdentifiable {
            case incomplete, complete
            
            static var identifiers = newIdentifierDictionary()
            
            var headerTitle: String {
                switch self {
                case .incomplete:
                    return "Incomplete Tasks"
                case .complete:
                    return "Complete Tasks"
                }
            }
            
            func subItems(in allItems: TaskItems) -> [DetailItem] {
                switch self {
                case .incomplete:
                    return allItems.incompleteTasks
                case .complete:
                    return allItems.completeTasks
                }
            }
            
            func shouldIncludeHeader(for items: TaskItems) -> Bool {
                switch self {
                case .incomplete:
                    return !items.incompleteTasks.isEmpty
                case .complete:
                    return !items.completeTasks.isEmpty
                }
            }
        }
    }
    
    // MARK: TaskItems
    private struct TaskItems {
        let incompleteTasks: [DetailItem]
        let completeTasks: [DetailItem]
        
        init(useCase: UseCase, tasks: [Task]) {
            var allTasks = tasks
            let p = allTasks.partition(by: { $0.isComplete(for: useCase) })
            incompleteTasks = allTasks[..<p].compactMap { Self.taskItem($0, useCase: useCase) }.sorted { $0.title < $1.title }
            completeTasks = allTasks[p...].compactMap { Self.taskItem($0, useCase: useCase) }.sorted { $0.title < $1.title }
        }
        
        private static func taskItem(_ task: Task, useCase: UseCase) -> DetailItem? {
            guard let id = task.id, let titleText = task.name else { return nil }
            let recordingsCountText = task.recordingsCountText(for: useCase)
            let bodyText = [recordingsCountText]
            return DetailItem(id: id, title: titleText, bodyText: bodyText)
        }
    }
    
    let navigationTitle: String = NSLocalizedString("View Use Case", comment: "view use case nav title")
    
    static let sectionFooterElementKind = "StartButtonFooter"
    
    var dataSource: UICollectionViewDiffableDataSource<Section.ID, DetailItem.ID>?
    
    private var useCase: UseCase
    private lazy var tasks: [Task]? = {
        return useCase.experiment?.tasks?.allObjects as? [Task]
    }()
    
    // MARK: Model Stores
    lazy var sectionsStore: ListModelStore<Section>? = {
        guard let taskListSection = taskListSection() else { return nil }
        let headerItemIds = UseCaseItem.allCases.map { $0.id }
        let useCaseHeaderSection = Section(id: .info, items: headerItemIds)
        return ListModelStore([useCaseHeaderSection, taskListSection])
    }()
    lazy var itemsStore: ListModelStore<DetailItem>? = {
        guard let taskItems = taskItems() else { return nil }
        let items = UseCaseItem.listItems(for: useCase) + taskItems
        return ListModelStore(items)
    }()
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    func itemID(at indexPath: IndexPath) -> UUID? {
        return dataSource?.itemIdentifier(for: indexPath)
    }
    
    // MARK: Configure Collection View
    
    func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout() { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let sectionID = Section.ID(rawValue: sectionIndex) else { return nil }
            switch sectionID {
            case .info:
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .firstItemInSection
//                config.footerMode = .supplementary
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
//                let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
//                let sectionFooter = NSCollectionLayoutBoundarySupplementaryItem(
//                    layoutSize: footerSize,
//                    elementKind: Self.sectionFooterElementKind,
//                    alignment: .bottom)
//                section.boundarySupplementaryItems = [sectionFooter]
                return section
            case .tasks:
                var configuration = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
                configuration.headerMode = .firstItemInSection
                configuration.headerTopPadding = 0
                let section = NSCollectionLayoutSection.list(using: configuration,
                                                             layoutEnvironment: layoutEnvironment)
                return section
            }
        }
    }
    
    func configureDataSource(for collectionView: UICollectionView) {
        
        let useCaseHeaderRegistration = createUseCaseHeaderRegistration()
        let useCaseCellRegistration = createUseCaseCellRegistration()
//        let footerRegistration = createStartButtonFooterRegistration()
        let taskContainerCellRegistration = createTaskContainerCellRegistration()
        let taskListCellRegistration = createTaskListCellRegistration()
        
        dataSource = UICollectionViewDiffableDataSource<Section.ID, DetailItem.ID>(collectionView: collectionView) {
            [weak self] (collectionView, indexPath, itemID) -> UICollectionViewCell? in
            guard let sectionID = Section.ID(rawValue: indexPath.section) else { return nil }
            
            switch sectionID {
            case .info:
                if indexPath.item == 0 {
                    return collectionView.dequeueConfiguredReusableCell(using: useCaseHeaderRegistration, for: indexPath, item: itemID)
                } else {
                    return collectionView.dequeueConfiguredReusableCell(using: useCaseCellRegistration, for: indexPath, item: itemID)
                }
            case .tasks:
                guard let item = self?.itemsStore?.fetchByID(itemID) else { return nil }
                if item.subItems.isEmpty {
                    return collectionView.dequeueConfiguredReusableCell(using: taskListCellRegistration, for: indexPath, item: itemID)
                } else {
                    return collectionView.dequeueConfiguredReusableCell(using: taskContainerCellRegistration, for: indexPath, item: itemID)
                }
            }
        }
        
//        dataSource?.supplementaryViewProvider = { (collectionView, elementKind, indexPath) in
//            return collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
//        }
    }
    
    func applyInitialSnapshots() {
        // Set the order for our sections
        let sections = Section.ID.allCases
        var snapshot = NSDiffableDataSourceSnapshot<Section.ID, DetailItem.ID>()
        snapshot.appendSections(sections)
        dataSource?.applySnapshotUsingReloadData(snapshot)
        applySectionSnapshots(sections, animated: false)
    }
    
    func refreshData() {
        reloadStores()
        guard var snapshot = dataSource?.snapshot() else { return }
        snapshot.reconfigureItems([UseCaseItem.completedTasks.id])
        dataSource?.apply(snapshot)
        applySectionSnapshots([Section.ID.tasks], animated: true)
    }
    
    private func applySectionSnapshots(_ sections: [Section.ID], animated: Bool) {
        // Set section snapshots for each section
        for sectionID in sections {
            guard let sectionSnapshot = createSnapshot(for: sectionID) else { continue }
            dataSource?.apply(sectionSnapshot, to: sectionID, animatingDifferences: animated)
        }
    }
    
    private func createSnapshot(for section: Section.ID) -> NSDiffableDataSourceSectionSnapshot<DetailItem.ID>? {
        guard let items = sectionsStore?.fetchByID(section)?.items else { return nil }
        var snapshot = NSDiffableDataSourceSectionSnapshot<DetailItem.ID>()
        
        func addItems(_ itemIds: [DetailItem.ID], to parent: DetailItem.ID?) {
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

// MARK: Model Store Configuration
extension UseCaseDetailViewModel {
    private func reloadStores() {
        guard let taskListSection = taskListSection(), let taskItems = taskItems() else { return }
        // Sections
        let headerItemIds = UseCaseItem.allCases.map { $0.id }
        let useCaseHeaderSection = Section(id: .info, items: headerItemIds)
        sectionsStore?.reload(with: [useCaseHeaderSection, taskListSection])
        // Items
        let items = UseCaseItem.listItems(for: useCase) + taskItems
        itemsStore?.reload(with: items)
    }
    
    private func taskListSection() -> Section? {
        guard let allTasks = tasks else { return nil }
        let taskItems = TaskItems(useCase: useCase, tasks: allTasks)
        let listItemsIds = TaskHeaders.HeaderType.allCases.filter { $0.shouldIncludeHeader(for: taskItems) }.map { $0.id }
        return Section(id: .tasks, items: listItemsIds)
    }
    
    private func taskItems() -> [DetailItem]? {
        guard let allTasks = tasks else { return nil }
        let taskItems = TaskItems(useCase: useCase, tasks: allTasks)
        let headerTypes = TaskHeaders.HeaderType.allCases
        let headerItems = headerTypes.map { DetailItem(id: $0.id, title: $0.headerTitle, subItems: $0.subItems(in: taskItems)) }
        return [headerItems, taskItems.incompleteTasks, taskItems.completeTasks].flatMap { $0 }
    }
}

// MARK: Cell Registration
extension UseCaseDetailViewModel {
    private func createUseCaseHeaderRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem.ID> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.itemsStore?.fetchByID(itemID) else { return }
            var content = UIListContentConfiguration.extraProminentInsetGroupedHeader()
            content.text = item.title
            cell.contentConfiguration = content
        }
    }
    
    private func createUseCaseCellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem.ID> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, DetailItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.itemsStore?.fetchByID(itemID) else { return }
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            content.image = item.image
            cell.contentConfiguration = content
        }
    }
    
    private func createStartButtonFooterRegistration() -> UICollectionView.SupplementaryRegistration<ButtonSupplementaryView> {
        return UICollectionView.SupplementaryRegistration<ButtonSupplementaryView>(elementKind: Self.sectionFooterElementKind) {
            (supplementaryView, elementKind, indexPath) in
            return
        }
    }
    
    private func createTaskContainerCellRegistration() -> UICollectionView.CellRegistration<ExpandableHeaderCell, DetailItem.ID> {
        return UICollectionView.CellRegistration<ExpandableHeaderCell, DetailItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.itemsStore?.fetchByID(itemID) else { return }
            cell.updateWithItem(item)
        }
    }
    
    private func createTaskListCellRegistration() -> UICollectionView.CellRegistration<OldListTextCell, DetailItem.ID> {
        return UICollectionView.CellRegistration<OldListTextCell, DetailItem.ID> { [weak self] (cell, indexPath, itemID) in
            guard let self = self, let item = self.itemsStore?.fetchByID(itemID) else { return }
            let cellModel = ListTextCellModel(detailItem: item)
            cell.updateWithItem(cellModel)
        }
    }
}
