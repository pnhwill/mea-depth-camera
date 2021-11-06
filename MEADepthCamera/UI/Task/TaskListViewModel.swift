//
//  TaskListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import Foundation

class TaskListViewModel: ListViewModel {
    
    private struct UseCaseHeader {
        enum ItemType: Int, CaseIterable {
            case sectionHeader, title, experiment, subjectID, completedTasks
            
            var id: UUID {
                UseCaseHeader.identifiers[self.rawValue]
            }
            
            func displayText(for useCase: UseCase) -> String? {
                switch self {
                case .sectionHeader:
                    return "Use Case"
                case .title:
                    return useCase.title
                case .experiment:
                    return useCase.experimentTitle ?? useCase.experiment?.title
                case .subjectID:
                    guard let subjectID = useCase.subjectID else { return nil }
                    return "Subject ID: " + subjectID
                case .completedTasks:
                    return "X out of X tasks completed"
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
            
//            var id: UUID {
//                switch self {
//                case .incomplete:
//                    return TaskHeaders.incompleteID
//                case .complete:
//                    return TaskHeaders.completeID
//                }
//            }
            
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
        }
        
        static let identifiers: [UUID] = {
            return HeaderType.allCases.map { _ in UUID() }
        }()
        
//        static let incompleteID = UUID()
//        static let completeID = UUID()
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
        let headerItemIds = UseCaseHeader.ItemType.allCases.map { $0.id }
        let useCaseHeaderSection = ListSection(id: .header, items: headerItemIds)
        let listItemsIds = TaskHeaders.HeaderType.allCases.map { $0.id }
        let taskListSection = ListSection(id: .list, items: listItemsIds)
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
}

// MARK: Model Store Configuration
extension TaskListViewModel {
    
    private func reloadItemStore() {
        guard let taskItems = taskItems() else { return }
        let items = useCaseItems() + taskItems
        itemsStore?.reload(with: items)
    }
    
    private func taskItems() -> [ListItem]? {
        guard let allTasks = tasks else { return nil }
        let taskItems = TaskItems(useCase: useCase, tasks: allTasks)
        let headerTypes = TaskHeaders.HeaderType.allCases
        let headerItems = headerTypes.map { ListItem(id: $0.id, title: $0.headerTitle, subItems: $0.subItems(in: taskItems)) }
        return [headerItems, taskItems.incompleteTasks, taskItems.completeTasks].flatMap { $0 }
    }
    
    private func useCaseItems() -> [ListItem] {
        let itemTypes = UseCaseHeader.ItemType.allCases
        let items = itemTypes.map { ListItem(id: $0.id, title: $0.displayText(for: useCase) ?? "?") }
        return items
    }
    
//    private func useCaseItem() -> ListItem? {
//        guard let id = useCase.id else { return nil }
//        let titleText = useCase.title ?? "?"
//        let subTitleText = useCase.experimentTitle ?? useCase.experiment?.title ?? "?"
//        let subjectID = useCase.subjectID ?? "?"
//        let subjectIDText = "Subject ID: " + subjectID
//        let completedTasksText = "X out of X tasks completed"
//        let bodyText = [subjectIDText, completedTasksText]
//        return ListItem(id: id, title: titleText, subTitle: subTitleText, bodyText: bodyText)
//    }
}
