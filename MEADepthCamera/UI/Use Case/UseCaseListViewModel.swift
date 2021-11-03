//
//  UseCaseListViewModel.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/27/21.
//

import UIKit
import CoreData
import Combine

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
    
    weak var delegate: UseCaseInteractionDelegate?
    
    var filter: UseCaseListViewModel.Filter = .all {
        didSet {
            reloadListStores()
        }
    }
    
    lazy var sectionsStore: ObservableModelStore<ListSection>? = {
        guard let items = sortedUseCases?.compactMap({ $0.id }) else { return nil }
        return ObservableModelStore([ListSection(id: .list, items: items)])
    }()
    
    lazy var itemsStore: ObservableModelStore<ListItem>? = {
        guard let items = sortedUseCases?.compactMap({ listItem(useCase: $0) }) else { return nil }
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
        return useCases?.filter { filter.shouldInclude(date: $0.date!) }//.sorted { $0.date! > $1.date! }
    }
    
    private var sortedUseCases: [UseCase]? {
        guard var useCases = filteredUseCases else { return nil }
        let p = useCases.partition(by: { !Filter.today.shouldInclude(date: $0.date!) })
        useCases[..<p].sort { $0.title! < $1.title! }
        useCases[p...].sort { $0.title! < $1.title! }
        return useCases
    }
    
    func useCase(with id: UUID?) -> UseCase? {
        return useCases?.first(where: { $0.id == id})
    }
    
    func listItem(useCase: UseCase) -> ListItem? {
        guard let id = useCase.id else { return nil }
        let titleText = useCase.title ?? "?"
        let subTitleText = useCase.experimentTitle ?? useCase.experiment?.title ?? "?"
        let dateText = useCase.dateTimeText(for: filter) ?? "?"
        let subjectID = useCase.subjectID ?? "?"
        let subjectIDText = "Subject ID: " + subjectID
        let bodyText = [subjectIDText, dateText]
        return ListItem(id: id, title: titleText, subTitle: subTitleText, bodyText: bodyText)
    }
    
    func add(completion: @escaping (UseCase) -> Void) {
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false) { useCase in
            completion(useCase)
        }
    }
    
    func delete(_ useCase: UseCase, completion: @escaping (Bool) -> Void) {
        dataProvider.delete(useCase) { success in
            completion(success)
        }
    }
}

extension UseCaseListViewModel {
    
    private func sortUseCases() {
        let todayFilter = Filter.today
        
        
    }

    private func reloadListStores() {
        guard let items = sortedUseCases?.compactMap({ listItem(useCase: $0) }),
              let itemIDs = sortedUseCases?.compactMap({ $0.id })
        else { return }
        sectionsStore?.merge(newModels: [ListSection(id: .list, items: itemIDs)])
        itemsStore?.reload(with: items)
    }
    
    private func addToListStores(_ useCase: UseCase) {
        guard let id = useCase.id,
              let item = listItem(useCase: useCase),
              var listSection = sectionsStore?.fetchByID(.list)
        else { return }
        listSection.items?.append(id)
        sectionsStore?.merge(newModels: [listSection])
        itemsStore?.merge(newModels: [item])
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
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let useCase = anObject as? UseCase,
              let id = useCase.id
        else { return }
        switch type {
        case .insert:
            print("INSERT")
            addToListStores(useCase)
        case .delete:
            print("DELETE")
            deleteFromListStores(id)
        case .move:
            print("MOVE")
            reloadListStores()
            delegate?.didUpdateUseCase(useCase)
        case .update:
            print("UPDATE")
            reconfigureItem(useCase)
            delegate?.didUpdateUseCase(useCase)
        @unknown default:
            reloadListStores()
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

