//
//  UseCaseListDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import CoreData

class UseCaseListViewModel: NSObject, ListViewModel {
    typealias ListCell = NewUseCaseListCell
    
    typealias HeaderCell = NewUseCaseListCell
    
    
    var navigationTitle: String = "Use Case List"
    
    var sectionsStore: AnyModelStore<Section>? {
        guard let items = useCases?.compactMap({ Item(object: $0)?.id }) else { return nil }
        return AnyModelStore([
            //Section(id: .header, items: []),
            Section(id: .list, items: items)
        ])
    }
    var itemsStore: AnyModelStore<Item>? {
        guard let items = useCases?.compactMap({ Item(object: $0) }) else { return nil }
        return AnyModelStore(items)
    }
    
    // Core Data provider
    private lazy var dataProvider: UseCaseProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = UseCaseProvider(with: container, fetchedResultsControllerDelegate: self)
        return provider
    }()
    
    private var useCases: [UseCase]? {
        return dataProvider.fetchedResultsController.fetchedObjects
    }
    
    
    
}

// MARK: NSFetchedResultsControllerDelegate
extension UseCaseListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    }
}

// MARK: UISearchResultsUpdating
extension UseCaseListViewModel {
    func updateSearchResults(for searchController: UISearchController) {
    }
}




class UseCaseListDataSource: NSObject {
    typealias UseCaseDeletedAction = (UUID?) -> Void
    typealias UseCaseChangedAction = () -> Void
    
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
    
    var navigationTitle: String = "Use Case List"
    
    var filter: Filter = .all
    
    var filteredUseCases: [UseCase]? {
        return useCases?.filter { filter.shouldInclude(date: $0.date!) }.sorted { $0.date! > $1.date! }
    }
    var useCases: [UseCase]? {
        return dataProvider.fetchedResultsController.fetchedObjects
    }
    
    private var useCaseDeletedAction: UseCaseDeletedAction?
    private var useCaseChangedAction: UseCaseChangedAction?
    
    // Core Data provider
    lazy var dataProvider: UseCaseProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = UseCaseProvider(with: container, fetchedResultsControllerDelegate: self)
        return provider
    }()
    
    init(useCaseDeletedAction: @escaping UseCaseDeletedAction, useCaseChangedAction: @escaping UseCaseChangedAction) {
        self.useCaseDeletedAction = useCaseDeletedAction
        self.useCaseChangedAction = useCaseChangedAction
        super.init()
    }
    
    // MARK: List Configuration
    
    func update(_ useCase: UseCase, completion: (Bool) -> Void) {
        saveUseCase(useCase) { id in
            let success = id != nil
            completion(success)
        }
    }
    
    func delete(at row: Int, completion: @escaping (Bool) -> Void) {
        if let useCase = self.useCase(at: row) {
            dataProvider.delete(useCase) { success in
                completion(success)
            }
        } else {
            completion(false)
        }
    }
    
    func add(completion: @escaping (UseCase) -> Void) {
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false) { useCase in
            completion(useCase)
        }
    }
    
    func useCase(at row: Int) -> UseCase? {
        return filteredUseCases?[row]
    }
    
    func useCase(with ID: UUID?) -> UseCase? {
        let useCase = useCases?.first(where: { $0.id == ID})
        return useCase
    }
    
    func index(for filteredIndex: Int) -> Int {
        let filteredUseCase = filteredUseCases?[filteredIndex]
        guard let index = useCases?.firstIndex(where: { $0.id == filteredUseCase?.id }) else {
            fatalError("Couldn't retrieve index in source array")
        }
        return index
    }
    
}

// MARK: UITableViewDataSource

extension UseCaseListDataSource: UITableViewDataSource {
    static let useCaseListCellIdentifier = "UseCaseListCell"
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredUseCases?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.useCaseListCellIdentifier, for: indexPath) as? UseCaseListCell else {
            fatalError("###\(#function): Failed to dequeue a UseCaseListCell. Check the cell reusable identifier in Main.storyboard.")
        }
        if let currentUseCase = useCase(at: indexPath.row) {
            let dateText = currentUseCase.dateTimeText(for: filter)
            let titleText = [currentUseCase.experimentTitle, currentUseCase.title].compactMap { $0 }.joined(separator: ": ")
            let recordingsCountText = currentUseCase.recordingsCountText()
            cell.configure(title: titleText, dateText: dateText, subjectIDText: currentUseCase.subjectID, recordingsCountText: recordingsCountText)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            return
        }
        let deletedUseCaseID = useCase(at: indexPath.row)?.id
        delete(at: indexPath.row) { success in
            if success {
                DispatchQueue.main.async {
                    tableView.reloadData()
                    self.useCaseDeletedAction?(deletedUseCaseID)
                }
            }
        }
    }
    
}

// MARK: Date/Time Formatters

extension UseCase {
    
    static let timeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()
    
    static let pastDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    static let todayDateFormatter: DateFormatter = {
        let format = NSLocalizedString("'Today at '%@", comment: "format string for dates occurring today")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = String(format: format, "hh:mm a")
        return dateFormatter
    }()
    
    func dateTimeText(for filter: UseCaseListDataSource.Filter) -> String? {
        guard let date = date else { return nil }
        let isInToday = Locale.current.calendar.isDateInToday(date)
        switch filter {
        case .today:
            return Self.timeFormatter.string(from: date)
        case .past:
            return Self.pastDateFormatter.string(from: date)
        case .all:
            if isInToday {
                return Self.todayDateFormatter.string(from: date)
            } else {
                return Self.pastDateFormatter.string(from: date)
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension UseCaseListDataSource: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        useCaseChangedAction?()
    }
}

// MARK: UISearchResultsUpdating

extension UseCaseListDataSource: UISearchResultsUpdating {
    
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
        
        useCaseChangedAction?()
    }
}

// MARK: Persistent Storage Interface

extension UseCaseListDataSource {
    
    private func saveUseCase(_ useCase: UseCase, completion: (UUID?) -> Void) {
        if let context = useCase.managedObjectContext {
            dataProvider.persistentContainer.saveContext(backgroundContext: context)
            context.refresh(useCase, mergeChanges: true)
            completion(useCase.id)
        } else {
            completion(nil)
        }
    }
    
}
