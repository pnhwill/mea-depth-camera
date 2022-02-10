//
//  UseCaseListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 2/9/22.
//

import CoreData

class UseCaseListViewModel:
    ListDataConverter<ListRepository<UseCaseProvider>, UseCaseListViewModel.Section, UseCaseListViewModel.Item>,
    ListViewModel
{
    struct Section: ListSectionViewModel {
        var listSection: ListSection {
            ListSection(id: name.rawValue,
                        items: itemIdentifiers,
                        canDelete: canDelete)
        }
        
        private let name: UseCase.SectionName
        private let itemIdentifiers: [ListItem.ID]
        private var canDelete: Bool {
            switch name {
            case .all: return true
            }
        }
        
        init?(sectionInfo: NSFetchedResultsSectionInfo) {
            guard let sectionName = UseCase.SectionName(rawValue: sectionInfo.name),
                  let objects = sectionInfo.objects as? [UseCase]
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
        
        init?(_ useCase: UseCase) {
            guard let name = useCase.title, let id = useCase.id else { return nil }
            self.name = name
            self.id = id
        }
    }
    
    let navigationTitle: String = "Use Cases"
}
