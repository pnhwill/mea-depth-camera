//
//  UseCaseListViewModel.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/27/21.
//

import UIKit
import CoreData

class UseCaseListViewModel: NSObject, ListViewModel {
    
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
    
    private struct HeaderItem {
        static let id = UUID()
        static let title = "Use Cases"
    }
    
    var filter: UseCaseListViewModel.Filter = .all {
        didSet {
            reloadListStores()
        }
    }
    
    // MARK: Data Stores
    lazy var sectionsStore: ObservableModelStore<ListSection>? = {
        guard let items = allItemIds else { return nil }
        return ObservableModelStore([ListSection(id: .list, items: items)])
    }()
    
    lazy var itemsStore: ObservableModelStore<ListItem>? = {
        guard let items = allItems else { return nil }
        return ObservableModelStore(items)
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
        return useCases?.filter { filter.shouldInclude(date: $0.date!) }
    }
    
    private var sortedUseCases: [UseCase]? {
        guard var useCases = filteredUseCases else { return nil }
        let p = useCases.partition(by: { !Filter.today.shouldInclude(date: $0.date!) })
        useCases[..<p].sort { $0.title! < $1.title! }
        useCases[p...].sort { $0.title! < $1.title! }
        return useCases
    }
    
    private var allItems: [ListItem]? {
        guard let listItems = sortedUseCases?.compactMap({ listItem(useCase: $0) }) else { return nil }
        return [ListItem(id: HeaderItem.id, title: HeaderItem.title)] + listItems
    }
    
    private var allItemIds: [UUID]? {
        guard let listItemIds = sortedUseCases?.compactMap({ $0.id }) else { return nil }
        return [HeaderItem.id] + listItemIds
    }
    
    func useCase(with id: UUID?) -> UseCase? {
        return useCases?.first(where: { $0.id == id})
    }
    
    func add(completion: @escaping (UseCase) -> Void) {
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false) { useCase in
            completion(useCase)
        }
    }
    
    func delete(_ id: UUID, completion: @escaping (Bool) -> Void) {
        guard let useCase = useCase(with: id) else { fatalError() }
        dataProvider.delete(useCase) { success in
            completion(success)
        }
    }
}

// MARK: Model Store Configuration
extension UseCaseListViewModel {
    
    private func listItem(useCase: UseCase) -> ListItem? {
        guard let id = useCase.id else { return nil }
        let titleText = useCase.title ?? "?"
        let subTitleText = useCase.experimentTitle ?? useCase.experiment?.title ?? "?"
        let dateText = useCase.dateTimeText(for: filter) ?? "?"
        let subjectID = useCase.subjectID ?? "?"
        let subjectIDText = "Subject ID: " + subjectID
        let bodyText = [subjectIDText, dateText]
        return ListItem(id: id, title: titleText, subTitle: subTitleText, bodyText: bodyText)
    }

    private func reloadListStores() {
        guard let items = allItems, let itemIDs = allItemIds else { return }
        sectionsStore?.merge(newModels: [ListSection(id: .list, items: itemIDs)])
        itemsStore?.reload(with: items)
    }
    
    private func addToListStores(_ useCase: UseCase) {
        guard let id = useCase.id,
              let item = listItem(useCase: useCase),
              var listSection = sectionsStore?.fetchByID(.list)
        else { return }
        listSection.items?.append(id)
        itemsStore?.merge(newModels: [item])
        sectionsStore?.merge(newModels: [listSection])
    }
    
    private func reconfigureItem(_ useCase: UseCase) {
        guard let item = listItem(useCase: useCase) else { return }
        itemsStore?.merge(newModels: [item])
    }
    
    private func deleteFromListStores(_ itemID: UUID) {
        guard var listSection = sectionsStore?.fetchByID(.list) else { return }
        listSection.items?.removeAll(where: { $0 == itemID })
        sectionsStore?.merge(newModels: [listSection])
        itemsStore?.deleteByID(itemID)
    }
}

// MARK: NSFetchedResultsControllerDelegate
extension UseCaseListViewModel: NSFetchedResultsControllerDelegate {
    /**
     controller(:didChange:at:for:newIndexPath:) is called as part of NSFetchedResultsControllerDelegate.
     
     Whenever a use case update requires a UI update, respond by updating the UI as follows.
     - add: make the new item visible and select it.
     - delete: preserve the current selection if any; otherwise select the first item.
     - move: reload all items, and send a useCaseDidChange notification to inform other parts of the app about the changes (an update of the object is assumed in this case).
     - update: reconfigure the item, make it visible, and select it.
     */
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let useCase = anObject as? UseCase,
              let id = useCase.id
        else { return }
        switch type {
        case .insert:
            addToListStores(useCase)
        case .delete:
            deleteFromListStores(id)
        case .move:
            reloadListStores()
            NotificationCenter.default.post(name: .useCaseDidChange, object: self, userInfo: [NotificationKeys.useCaseId: id])
        case .update:
            reconfigureItem(useCase)
            NotificationCenter.default.post(name: .useCaseDidChange, object: self, userInfo: [NotificationKeys.useCaseId: id])
        @unknown default:
            reloadListStores()
            NotificationCenter.default.post(name: .useCaseDidChange, object: self, userInfo: [NotificationKeys.useCaseId: id])
        }
    }
}

// MARK: UISearchResultsUpdating
extension UseCaseListViewModel: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let predicate: NSPredicate
        if let userInput = searchController.searchBar.text, !userInput.isEmpty {
            predicate = NSPredicate(format: "(title CONTAINS[cd] %@) OR (subjectID CONTAINS[cd] %@) OR (experimentTitle CONTAINS[cd] %@)", userInput, userInput, userInput)
        } else {
            predicate = NSPredicate(value: true)
        }

        dataProvider.fetchedResultsController.fetchRequest.predicate = predicate
        do {
            try dataProvider.fetchedResultsController.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        
        reloadListStores()
    }
}

