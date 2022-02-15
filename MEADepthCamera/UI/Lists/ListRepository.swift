//
//  ListRepository.swift
//  MEADepthCamera
//
//  Created by Will on 2/2/22.
//

import CoreData
import Combine

// MARK: ListRepositoryProtocol

protocol ListRepositoryProtocol {
    
    associatedtype Object: ListObject
    
    var objects: [Object] { get }
    var sections: [NSFetchedResultsSectionInfo] { get }
    var didChangeSectionsPublisher: AnyPublisher<[NSFetchedResultsSectionInfo], Never> { get }
    var didInsertObjectPublisher: AnyPublisher<Object, Never> { get }
    var didDeleteObjectPublisher: AnyPublisher<Object.ID, Never> { get }
    var didUpdateObjectPublisher: AnyPublisher<Object, Never> { get }
    
    init()

    func attachEventListeners(
        addItem: AnyPublisher<Void, Never>,
        deleteItem: AnyPublisher<ListItem.ID, Never>,
        searchTerm: AnyPublisher<String, Never>)
}

// MARK: ListRepository Class

final class ListRepository<Provider: ListDataProvider>:
    NSObject,
    ListRepositoryProtocol,
    NSFetchedResultsControllerDelegate
{
    typealias Object = Provider.Object
    
    var objects: [Object] {
        dataProvider.fetchedResultsController.fetchedObjects ?? []
    }
    var sections: [NSFetchedResultsSectionInfo] {
        dataProvider.fetchedResultsController.sections ?? []
    }
    
    var didChangeSectionsPublisher: AnyPublisher<[NSFetchedResultsSectionInfo], Never> {
        didChangeSectionsSubject.eraseToAnyPublisher()
    }
    var didInsertObjectPublisher: AnyPublisher<Object, Never> {
        didInsertObjectSubject.eraseToAnyPublisher()
    }
    var didDeleteObjectPublisher: AnyPublisher<Object.ID, Never> {
        didDeleteObjectSubject.eraseToAnyPublisher()
    }
    var didUpdateObjectPublisher: AnyPublisher<Object, Never> {
        didUpdateObjectSubject.eraseToAnyPublisher()
    }
    
    func attachEventListeners(
        addItem: AnyPublisher<Void, Never>,
        deleteItem: AnyPublisher<ListItem.ID, Never>,
        searchTerm: AnyPublisher<String, Never>
    ) {
        addItem
            .debounce(for: .seconds(0.1), scheduler: RunLoop.current)
            .sink { [weak self] in self?.add() }
            .store(in: &inputBindings)
        
        deleteItem
            .sink { [weak self] id in self?.delete(id) }
            .store(in: &inputBindings)
        
        searchTerm
            .debounce(for: .seconds(0.1), scheduler: RunLoop.current)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchQuery = query
            }
            .store(in: &inputBindings)
    }
    
    // MARK: Private
    
    private var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            search(query: searchQuery)
        }
    }
    
    private var inputBindings = Set<AnyCancellable>(minimumCapacity: 3)
    
    private lazy var dataProvider: Provider = Provider(fetchedResultsControllerDelegate: self)
    
    private var didChangeSectionsSubject = PassthroughSubject<[NSFetchedResultsSectionInfo], Never>()
    private var didInsertObjectSubject = PassthroughSubject<Object, Never>()
    private var didDeleteObjectSubject = PassthroughSubject<Object.ID, Never>()
    private var didUpdateObjectSubject = PassthroughSubject<Object, Never>()
    
    private func search(query: String) {
        let predicate: NSPredicate
        if query.isEmpty {
            predicate = NSPredicate(value: true)
        } else {
            predicate = NSPredicate(format: Object.searchFormat, argumentArray: Array(repeating: query, count: Object.searchKeys.count))
        }
        dataProvider.fetchedResultsController.fetchRequest.predicate = predicate
        do {
            try dataProvider.fetchedResultsController.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        didChangeSectionsSubject.send(sections)
    }
    
    private func add() {
        searchQuery = ""
        dataProvider.add(in: dataProvider.persistentContainer.viewContext, shouldSave: false)
    }
    
    private func delete(_ id: ListItem.ID) {
        guard let object = Provider.fetchObject(with: id) else { return }
        dataProvider.delete(object)
    }
    
    // MARK: NSFetchedResultsControllerDelegate
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?)
    {
        guard let object = anObject as? Object else { return }
        switch type {
        case .insert:
            didInsertObjectSubject.send(object)
            didChangeSectionsSubject.send(sections)
        case .delete:
            didDeleteObjectSubject.send(object.id)
            didChangeSectionsSubject.send(sections)
        case .move:
            didUpdateObjectSubject.send(object)
            didChangeSectionsSubject.send(sections)
        case .update:
            didUpdateObjectSubject.send(object)
        @unknown default:
            didUpdateObjectSubject.send(object)
            didChangeSectionsSubject.send(sections)
        }
    }
}

