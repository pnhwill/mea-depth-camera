//
//  TaskListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import UIKit
import CoreData

/// A ListViewModel for the TaskListViewController.
class TaskListViewModel: NSObject, ListViewModel {
    
    private enum Filter {
        case all, customOnly
        
        func shouldInclude(_ task: Task) -> Bool {
            switch self {
            case .customOnly:
                return !task.isDefault
            case .all:
                return true
            }
        }
    }
    
    // MARK: TaskHeaders
    private struct TaskHeaders {
        enum HeaderType: Int, CaseIterable {
            case sectionHeader, standard, custom
            
            var headerTitle: String {
                switch self {
                case .sectionHeader:
                    return "Tasks"
                case .standard:
                    return "Default"
                case .custom:
                    return "Custom"
                }
            }
            
            var id: UUID {
                TaskHeaders.identifiers[self.rawValue]
            }
            
            func subItems(in allItems: TaskItems) -> [ListItem] {
                switch self {
                case .standard:
                    return allItems.standardTasks
                case .custom:
                    return allItems.customTasks
                default:
                    return []
                }
            }
            
            func shouldIncludeHeader(for items: TaskItems) -> Bool {
                switch self {
                case .standard:
                    return !items.standardTasks.isEmpty
                case .custom:
                    return !items.customTasks.isEmpty
                default:
                    return true
                }
            }
        }
        
        static let identifiers: [UUID] = {
            return HeaderType.allCases.map { _ in UUID() }
        }()
    }
    
    // MARK: TaskItems
    private struct TaskItems {
        let standardTasks: [ListItem]
        let customTasks: [ListItem]
        
        init(tasks: [Task]) {
            var allTasks = tasks
            let p = allTasks.partition(by: { $0.isDefault })
            customTasks = allTasks[..<p].compactMap { Self.taskItem($0) }.sorted { $0.title < $1.title }
            standardTasks = allTasks[p...].compactMap { Self.taskItem($0) }.sorted { $0.title < $1.title }
        }
        
        static func taskItem(_ task: Task) -> ListItem? {
            guard let id = task.id, let titleText = task.name, let bodyText = task.fileNameLabel else { return nil }
            return ListItem(id: id, title: titleText, bodyText: [bodyText])
        }
    }
    
    private var filter: Filter = .all
    
    // MARK: Model Stores
    lazy var sectionsStore: ObservableModelStore<Section>? = {
        guard let taskListSection = taskListSection() else { return nil }
        return ObservableModelStore([taskListSection])
    }()
    lazy var itemsStore: ObservableModelStore<Item>? = {
        guard let taskItems = taskItems() else { return nil }
        return ObservableModelStore(taskItems)
    }()
    
    private lazy var dataProvider: TaskProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = TaskProvider(with: container, fetchedResultsControllerDelegate: self)
        return provider
    }()
    
    private var tasks: [Task]? {
        return dataProvider.fetchedResultsController.fetchedObjects
    }
    
    private var filteredTasks: [Task]? {
        tasks?.filter { filter.shouldInclude($0) }
    }
    
    func setDeleteMode(_ isDeleting: Bool) {
        filter = isDeleting ? .customOnly : .all
        reloadStores()
    }
    
    func task(with id: UUID) -> Task? {
        return tasks?.first(where: { $0.id == id})
    }
    
    func add(completion: @escaping (Task) -> Void) {
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false) { task in
            completion(task)
        }
    }
    
    func delete(_ id: UUID, completion: @escaping (Bool) -> Void) {
        guard let task = task(with: id) else { return }
        dataProvider.delete(task) { success in
            completion(success)
        }
    }
}

// MARK: Model Store Configuration
extension TaskListViewModel {
    
    private func reloadStores() {
        guard let items = taskItems(), let section = taskListSection() else { return }
        itemsStore?.reload(with: items)
        sectionsStore?.merge(newModels: [section])
    }
    
    private func addToListStores(_ newTask: Task) {
//        guard let id = task.id,
//              let item = TaskItems.taskItem(task),
//              var listSection = sectionsStore?.fetchByID(.list),
//              var taskItems = taskItems()
//        else { return }
//        listSection.items?.append(id)
//        taskItems.append(item)
//        itemsStore?.merge(newModels: [item])
//
//        sectionsStore?.merge(newModels: [listSection])
        guard var tasks = tasks else { return }
        tasks.append(newTask)
        let taskItems = TaskItems(tasks: tasks)
        let headerTypes = TaskHeaders.HeaderType.allCases
        let headerItems = headerTypes.map { ListItem(id: $0.id, title: $0.headerTitle, subItems: $0.subItems(in: taskItems)) }
        let headerIds = headerTypes.map { $0.id }
        let section = ListSection(id: .list, items: headerIds)
        itemsStore?.merge(newModels: headerItems)
        sectionsStore?.merge(newModels: [section])
    }
    
    private func reconfigureItem(_ task: Task) {
        guard let item = TaskItems.taskItem(task) else { return }
        itemsStore?.merge(newModels: [item])
    }
    
    private func deleteFromListStores(_ itemID: UUID) {
        guard var listSection = sectionsStore?.fetchByID(.list) else { return }
        listSection.items?.removeAll(where: { $0 == itemID })
        sectionsStore?.merge(newModels: [listSection])
        itemsStore?.deleteByID(itemID)
    }
    
    private func taskItems() -> [ListItem]? {
        guard let allTasks = filteredTasks else { return nil }
        let taskItems = TaskItems(tasks: allTasks)
        let headerTypes = TaskHeaders.HeaderType.allCases
        let headerItems = headerTypes.map { ListItem(id: $0.id, title: $0.headerTitle, subItems: $0.subItems(in: taskItems)) }
        return [headerItems, taskItems.standardTasks, taskItems.customTasks].flatMap { $0 }
    }
    
    private func taskListSection() -> ListSection? {
        guard let allTasks = filteredTasks else { return nil }
        let taskItems = TaskItems(tasks: allTasks)
        let listItemsIds = TaskHeaders.HeaderType.allCases
            .filter { $0.shouldIncludeHeader(for: taskItems) }
            .map { $0.id }
        return ListSection(id: .list, items: listItemsIds)
    }
}

extension TaskListViewModel: NSFetchedResultsControllerDelegate {
    /**
     controller(:didChange:at:for:newIndexPath:) is called as part of NSFetchedResultsControllerDelegate.
     
     Whenever a task update requires a UI update, respond by updating the UI as follows.
     - add: make the new item visible and select it.
     - delete: preserve the current selection if any; otherwise select the first item.
     - move: reload all items, and send a taskDidChange notification to inform other parts of the app about the changes (an update of the object is assumed in this case).
     - update: reconfigure the item, make it visible, and select it.
     */
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        debugPrint("fsekrugieufvh")
        guard let task = anObject as? Task,
              let id = task.id
        else { return }
        switch type {
        case .insert:
            addToListStores(task)
        case .delete:
            deleteFromListStores(id)
        case .move:
            reloadStores()
            NotificationCenter.default.post(name: .taskDidChange, object: self, userInfo: [NotificationKeys.taskId: id])
        case .update:
            reconfigureItem(task)
            NotificationCenter.default.post(name: .taskDidChange, object: self, userInfo: [NotificationKeys.taskId: id])
        @unknown default:
            reloadStores()
            NotificationCenter.default.post(name: .taskDidChange, object: self, userInfo: [NotificationKeys.taskId: id])
        }
    }
}

// MARK: UISearchResultsUpdating
extension TaskListViewModel: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let predicate: NSPredicate
        if let userInput = searchController.searchBar.text, !userInput.isEmpty {
            predicate = NSPredicate(format: "(name CONTAINS[cd] %@) OR (fileNameLabel CONTAINS[cd] %@) OR (instructions CONTAINS[cd] %@)", userInput, userInput, userInput)
        } else {
            predicate = NSPredicate(value: true)
        }

        dataProvider.fetchedResultsController.fetchRequest.predicate = predicate
        do {
            try dataProvider.fetchedResultsController.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        
        reloadStores()
    }
}
