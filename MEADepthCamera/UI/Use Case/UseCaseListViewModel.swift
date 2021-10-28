//
//  UseCaseListViewModel.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/27/21.
//

import UIKit
import CoreData

class UseCaseListViewModel: NSObject, ListViewModel {

    typealias ListDiffableDataSource = UICollectionViewDiffableDataSource<ListSection.ID, ListItem.ID>
    typealias ListCell = ListTextCell
    typealias HeaderCell = UseCaseListCell
    
    enum Filter: Int {
        case today
        case past
        case all

        func shouldInclude(date: Date) -> Bool {
            let isInToday = Locale.current.calendar.isDateInToday(date)
            switch self {
            case .today:
                return isInToday
            case .past:
                return (date < Date()) && !isInToday
            case .all:
                return true
            }
        }
    }
    
    var dataSource: ListDiffableDataSource?
    
    var filter: UseCaseListViewModel.Filter = .all
    
    lazy var sectionsStore: AnyModelStore<ListSection>? = {
        guard let items = filteredUseCases?.compactMap({ ListItem(object: $0)?.id }) else { return nil }
        return AnyModelStore([ListSection(id: .list, items: items)])
    }()
    
    lazy var itemsStore: AnyModelStore<ListItem>? = {
        guard let items = filteredUseCases?.compactMap({ ListItem(object: $0) }) else { return nil }
        return AnyModelStore(items)
    }()
    
    private lazy var dataProvider: UseCaseProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = UseCaseProvider(with: container, fetchedResultsControllerDelegate: self)
        return provider
    }()
    
    private var useCases: [UseCase]? {
        return dataProvider.fetchedResultsController.fetchedObjects
    }

    private var filteredUseCases: [UseCase]? {
        return useCases?.filter { filter.shouldInclude(date: $0.date!) }.sorted { $0.date! > $1.date! }
    }
    
    func configure(_ listCell: ListTextCell) {
        listCell.delegate = self
    }
    
    func update(_ useCase: UseCase, completion: (Bool) -> Void) {
        if let context = useCase.managedObjectContext {
            dataProvider.persistentContainer.saveContext(backgroundContext: context, with: .updateUseCase)
//            context.refresh(useCase, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func add(completion: @escaping (UseCase) -> Void) {
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false) { useCase in
            completion(useCase)
        }
    }
    
    private func updateStores() {
        guard let items = filteredUseCases?.compactMap({ ListItem(object: $0) }) else { return }
        let itemIDs = items.map({ $0.id })
        sectionsStore?.update(with: [ListSection(id: .list, items: itemIDs)])
        itemsStore?.update(with: items)
    }
}

// MARK: ListTextCellDelegate
extension UseCaseListViewModel: ListTextCellDelegate {
    func contentConfiguration(for item: ListItem) -> TextCellContentConfiguration? {
        guard let useCase = item.object as? UseCase else { fatalError() }
        guard let titleText = useCase.title,
              let experimentText = useCase.experimentTitle,
              let dateText = useCase.dateTimeText(for: .all),
              let subjectID = useCase.subjectID
        else { return nil }
        let subjectIDText = "Subject ID: " + subjectID
        let completedTasksText = "X out of X tasks completed"
        let bodyText = [subjectIDText, dateText, completedTasksText]
        let content = TextCellContentConfiguration(titleText: titleText, subtitleText: experimentText, bodyText: bodyText)
        return content
    }
    
    func delete(objectFor item: ListItem) {
        guard let useCase = item.object as? UseCase else { fatalError() }
        dataProvider.delete(useCase) { [weak self] success in
            if let dataSource = self?.dataSource {
                var snapshot = dataSource.snapshot()
                snapshot.deleteItems([item.id])
                dataSource.apply(snapshot)
            }
        }
    }
}

// MARK: UseCaseInteractionDelegate
extension UseCaseListViewModel: UseCaseInteractionDelegate {
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
        if let dataSource = dataSource {
//            var snapshot = dataSource.snapshot()
//            snapshot.reconfigureItems([itemID])
//            dataSource.apply(snapshot)
        }
    }
}

// MARK: UISearchResultsUpdating
extension UseCaseListViewModel: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
    }
}

// MARK: NSFetchedResultsControllerDelegate
extension UseCaseListViewModel: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
//        print("controller did change object")
        fetchedResultsController(didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
//        print(#function)
    }
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        updateStores()
//        applySnapshotFromListStore()
//        print(#function)
    }
}
