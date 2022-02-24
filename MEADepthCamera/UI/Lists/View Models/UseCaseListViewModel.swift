//
//  UseCaseListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 2/9/22.
//

import CoreData

final class UseCaseListViewModel:
    ListDataConverter<ListRepository<UseCaseProvider>, UseCaseListViewModel.Section, UseCaseListViewModel.Item>,
    ListViewModel
{
    struct Section: ListSectionViewModel {
        var listSection: ListSection {
            ListSection(
                id: name,
                items: itemIdentifiers,
                canDelete: canDelete)
        }
        
        private let name: String
        private let itemIdentifiers: [ListItem.ID]
        private var canDelete: Bool { true }
        
        init?(sectionInfo: NSFetchedResultsSectionInfo) {
            guard let objects = sectionInfo.objects as? [UseCase] else { return nil }
            self.name = sectionInfo.name
            self.itemIdentifiers = objects.compactMap { $0.id }
        }
    }
    
    struct Item: ListItemViewModel {
        var listItem: ListItem {
            ListItem(
                id: id,
                title: name,
                bodyText: [
                    subjectID,
                    experiment,
                    date,
                ])
        }
        
        private let id: UUID
        private let name: String
        private let experiment: String
        private let date: String
        private let subjectID: String
        
        init?(_ useCase: UseCase) {
            guard let id = useCase.id,
                  let name = useCase.title,
                  let date = useCase.dateTimeText()
            else { return nil }
            let experiment = useCase.experimentTitle ?? "?"
            self.id = id
            self.name = name
            self.experiment = experiment
            self.date = date
            self.subjectID = useCase.subjectIDText
        }
    }
    
    let navigationTitle: String = "Use Cases"
}
