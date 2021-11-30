//
//  TaskListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import UIKit

class TaskListViewModel: ListViewModel {
    
    private struct UseCaseHeader {
        enum ItemType: Int, CaseIterable {
            case sectionHeader, title, experiment, subjectID, completedTasks
            
            var id: UUID {
                UseCaseHeader.identifiers[self.rawValue]
            }
            
            var cellImage: UIImage? {
                switch self {
                case .experiment:
                    return UIImage(systemName: "chart.bar.xaxis")
                case .subjectID:
                    return UIImage(systemName: "person.fill.viewfinder")
                case .completedTasks:
                    return UIImage(systemName: "checklist")
                default:
                    return nil
                }
            }
            
            func displayText(for useCase: UseCase) -> String? {
                switch self {
                case .sectionHeader:
                    return "Current Use Case"
                case .title:
                    return useCase.title
                case .experiment:
                    return useCase.experimentTitle ?? useCase.experiment?.title
                case .subjectID:
                    guard let subjectID = useCase.subjectID else { return nil }
                    return "Subject ID: " + subjectID
                case .completedTasks:
                    return "\(useCase.completedTasks) out of \(useCase.tasksCount) tasks completed"
                }
            }
            
        }
        
        static let identifiers: [UUID] = {
            return ItemType.allCases.map { _ in UUID() }
        }()
    }
    
    private struct TaskHeaders {
        enum HeaderType: Int, CaseIterable {
            case sectionHeader, incomplete, complete
            
            var headerTitle: String {
                switch self {
                case .sectionHeader:
                    return "Tasks"
                case .incomplete:
                    return "Incomplete Tasks"
                case .complete:
                    return "Complete Tasks"
                }
            }
            
            var id: UUID {
                TaskHeaders.identifiers[self.rawValue]
            }
            
            func subItems(in allItems: TaskItems) -> [ListItem] {
                switch self {
                case .incomplete:
                    return allItems.incompleteTasks
                case .complete:
                    return allItems.completeTasks
                default:
                    return []
                }
            }
            
            func shouldIncludeHeader(for items: TaskItems) -> Bool {
                switch self {
                case .incomplete:
                    return !items.incompleteTasks.isEmpty
                case .complete:
                    return !items.completeTasks.isEmpty
                default:
                    return true
                }
            }
        }
        
        static let identifiers: [UUID] = {
            return HeaderType.allCases.map { _ in UUID() }
        }()
    }
    
    private struct TaskItems {
        let incompleteTasks: [ListItem]
        let completeTasks: [ListItem]
        
        init(useCase: UseCase, tasks: [Task]) {
            var allTasks = tasks
            let p = allTasks.partition(by: { $0.isComplete(for: useCase) })
            incompleteTasks = allTasks[..<p].compactMap { Self.taskItem($0, useCase: useCase) }.sorted { $0.title < $1.title }
            completeTasks = allTasks[p...].compactMap { Self.taskItem($0, useCase: useCase) }.sorted { $0.title < $1.title }
        }
        
        private static func taskItem(_ task: Task, useCase: UseCase) -> ListItem? {
            guard let id = task.id, let titleText = task.name else { return nil }
            let recordingsCountText = task.recordingsCountText(for: useCase)
            let bodyText = [recordingsCountText]
            return ListItem(id: id, title: titleText, bodyText: bodyText)
        }
    }
    
    lazy var sectionsStore: ObservableModelStore<Section>? = {
        guard let taskListSection = taskListSection() else { return nil }
        let headerItemIds = UseCaseHeader.ItemType.allCases.map { $0.id }
        let useCaseHeaderSection = ListSection(id: .header, items: headerItemIds)
        return ObservableModelStore([useCaseHeaderSection, taskListSection])
    }()
    lazy var itemsStore: ObservableModelStore<Item>? = {
        guard let taskItems = taskItems() else { return nil }
        let items = useCaseItems() + taskItems
        return ObservableModelStore(items)
    }()
    
    private var useCase: UseCase
    private lazy var tasks: [Task]? = {
        return useCase.experiment?.tasks?.allObjects as? [Task]
    }()
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
    
    func task(with id: UUID) -> Task? {
        return tasks?.first(where: { $0.id == id})
    }
    
    func reloadStores() {
        guard let taskItems = taskItems(), let taskListSection = taskListSection() else { return }
        let headerItemIds = UseCaseHeader.ItemType.allCases.map { $0.id }
        let useCaseHeaderSection = ListSection(id: .header, items: headerItemIds)
        let items = useCaseItems() + taskItems
        let sections = [useCaseHeaderSection, taskListSection]
        itemsStore?.reload(with: items)
        sectionsStore?.reload(with: sections)
    }
}

// MARK: Model Store Configuration
extension TaskListViewModel {
    
    private func taskItems() -> [ListItem]? {
        guard let allTasks = tasks else { return nil }
        let taskItems = TaskItems(useCase: useCase, tasks: allTasks)
        let headerTypes = TaskHeaders.HeaderType.allCases
        let headerItems = headerTypes.map { ListItem(id: $0.id, title: $0.headerTitle, subItems: $0.subItems(in: taskItems)) }
        return [headerItems, taskItems.incompleteTasks, taskItems.completeTasks].flatMap { $0 }
    }
    
    private func useCaseItems() -> [ListItem] {
        let itemTypes = UseCaseHeader.ItemType.allCases
        let headerItems = itemTypes[..<2].map { ListItem(id: $0.id, title: $0.displayText(for: useCase) ?? "?", image: $0.cellImage) }
        let items = itemTypes[2...].map { ListItem(id: $0.id, title: "", subTitle: $0.displayText(for: useCase) ?? "?", image: $0.cellImage) }
        return headerItems + items
    }
    
    private func taskListSection() -> ListSection? {
        guard let allTasks = tasks else { return nil }
        let taskItems = TaskItems(useCase: useCase, tasks: allTasks)
        let listItemsIds = TaskHeaders.HeaderType.allCases.filter { $0.shouldIncludeHeader(for: taskItems) }.map { $0.id }
        return ListSection(id: .list, items: listItemsIds)
    }
}
