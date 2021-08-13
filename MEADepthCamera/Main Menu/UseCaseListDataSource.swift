//
//  UseCaseListDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit
import CoreData

class UseCaseListDataSource: NSObject {
    typealias UseCaseDeletedAction = () -> Void
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
    
    var filter: Filter = .today
    
    var filteredUseCases: [UseCase]? {
        return fetchedResultsController.fetchedObjects?.filter { filter.shouldInclude(date: $0.date!) }.sorted { $0.date! > $1.date! }
    }
    
    private var useCaseDeletedAction: UseCaseDeletedAction?
    private var useCaseChangedAction: UseCaseChangedAction?
    
    // Persistent storage
    
    private(set) lazy var persistentContainer: PersistentContainer = {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer
    }()
    
    private lazy var fetchedResultsController: NSFetchedResultsController<UseCase> = {
        let fetchRequest: NSFetchRequest<UseCase> = UseCase.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: UseCase.Name.date, ascending: true)]
        
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: persistentContainer.viewContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        do {
            try controller.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        return controller
    }()
    
    init(useCaseDeletedAction: @escaping UseCaseDeletedAction, useCaseChangedAction: @escaping UseCaseChangedAction) {
        self.useCaseDeletedAction = useCaseDeletedAction
        self.useCaseChangedAction = useCaseChangedAction
        super.init()
    }
    
    // MARK: Persistent Storage Interface
    
    func update(_ useCase: UseCase, at row: Int, completion: (Bool) -> Void) {
        if let context = useCase.managedObjectContext {
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(useCase, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func delete(at row: Int, completion: (Bool) -> Void) {
        if let useCase = self.useCase(at: row), let context = useCase.managedObjectContext {
            context.delete(useCase)
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(useCase, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func add(_ useCase: UseCase, completion: (Bool) -> Void) {
        if let context = useCase.managedObjectContext {
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(useCase, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func useCase(at row: Int) -> UseCase? {
        return filteredUseCases?[row]
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
            cell.configure(title: currentUseCase.title, dateText: dateText, subjectIDText: currentUseCase.subjectID, numRecordings: Int(currentUseCase.recordingsCount))
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard  editingStyle == .delete else {
            return
        }
        delete(at: indexPath.row) { success in
            if success {
                DispatchQueue.main.async {
                    tableView.reloadData()
                    self.useCaseDeletedAction?()
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

// MARK: - UISearchResultsUpdating

extension UseCaseListDataSource: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let predicate: NSPredicate
        if let userInput = searchController.searchBar.text, !userInput.isEmpty {
            predicate = NSPredicate(format: "title CONTAINS[cd] %@", userInput)
        } else {
            predicate = NSPredicate(value: true)
        }

        fetchedResultsController.fetchRequest.predicate = predicate
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }

        useCaseChangedAction?()
    }
}
