//
//  ListDataConverter.swift
//  MEADepthCamera
//
//  Created by Will on 2/7/22.
//

import CoreData
import Combine

protocol CoreDataSectionConverting {
    init?(sectionInfo: NSFetchedResultsSectionInfo)
}

protocol CoreDataObjectConverting {
    associatedtype Object: ListObject
    init?(_ object: Object)
}

typealias ListSectionViewModel = ListSectionRepresentable & CoreDataSectionConverting
typealias ListItemViewModel = ListItemRepresentable & CoreDataObjectConverting

// MARK: ListDataConverter

class ListDataConverter<Repository: ListRepositoryProtocol, Section: ListSectionViewModel, Item: ListItemViewModel>
where
    Repository.Object == Item.Object
{
    private(set) lazy var reloadSectionsPublisher: AnyPublisher<[ListSection], Never> = createSectionsPublisher(repository.didChangeSectionsPublisher)
    private(set) lazy var reconfigureItemPublisher: AnyPublisher<ListItem, Never> = createItemPublisher(repository.didUpdateObjectPublisher)
    private(set) lazy var addItemPublisher: AnyPublisher<ListItem, Never> = createItemPublisher(repository.didInsertObjectPublisher)
    private(set) lazy var deleteItemPublisher: AnyPublisher<ListItem.ID, Never> = createItemIDPublisher(repository.didDeleteObjectPublisher)
    
    private let repository = Repository()
    
    func fetchData() -> ([ListSection], [ListItem]) {
        let listItems = repository.objects.compactMap { Item($0)?.listItem }
        let listSections = repository.sections.compactMap { Section(sectionInfo: $0)?.listSection }
        return (listSections, listItems)
    }
    
    func bindToView(
        addItem: AnyPublisher<Void, Never>,
        deleteItem: AnyPublisher<ListItem.ID, Never>,
        searchTerm: AnyPublisher<String, Never>
    ) {
        repository.attachEventListeners(addItem: addItem, deleteItem: deleteItem, searchTerm: searchTerm)
    }
}

extension ListDataConverter {
    private func createSectionsPublisher(_ sectionInfoPublisher: AnyPublisher<[NSFetchedResultsSectionInfo], Never>) -> AnyPublisher<[ListSection], Never> {
        return sectionInfoPublisher
            .map { $0.compactMap { Section(sectionInfo: $0)?.listSection } }
            .eraseToAnyPublisher()
    }
    
    private func createItemPublisher(_ objectPublisher: AnyPublisher<Repository.Object, Never>) -> AnyPublisher<ListItem, Never> {
        return objectPublisher
            .compactMap { Item($0)?.listItem }
            .eraseToAnyPublisher()
    }
    
    private func createItemIDPublisher(_ objectIDPublisher: AnyPublisher<Repository.Object.ID, Never>) -> AnyPublisher<ListItem.ID, Never> {
        return objectIDPublisher
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
