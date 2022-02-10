//
//  TaskListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 2/9/22.
//

import CoreData

class TaskListViewModel:
    ListDataConverter<ListRepository<TaskProvider>, TaskListViewModel.Section, TaskListViewModel.Item>,
    ListViewModel
{
    struct Section: ListSectionViewModel {
        var listSection: ListSection {
            ListSection(id: name.rawValue,
                        items: itemIdentifiers,
                        canDelete: canDelete)
        }
        
        private let name: Task.SectionName
        private let itemIdentifiers: [ListItem.ID]
        private var canDelete: Bool {
            switch name {
            case .all: return false
            case .custom: return true
            case .standard: return false
            }
        }
        
        init?(sectionInfo: NSFetchedResultsSectionInfo) {
            guard let sectionName = Task.SectionName(rawValue: sectionInfo.name),
                  let objects = sectionInfo.objects as? [Task]
            else { return nil }
            self.name = sectionName
            self.itemIdentifiers = objects.compactMap { $0.id }
        }
    }
    
    struct Item: ListItemViewModel {
        var listItem: ListItem {
            ListItem(id: id, title: name)
        }
        
        private let name: String
        private let id: UUID
        
        init?(_ task: Task) {
            guard let name = task.name, let id = task.id else { return nil }
            self.name = name
            self.id = id
        }
    }
    
    let navigationTitle: String = "Tasks"
}
