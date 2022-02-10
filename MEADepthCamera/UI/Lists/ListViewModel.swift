//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/18/22.
//

import Combine
import CoreData

protocol NavigationTitleProviding {
    var navigationTitle: String { get }
}

// MARK: ListViewModel

protocol ListViewModel: NavigationTitleProviding {
    
    var reloadSectionsPublisher: AnyPublisher<[ListSection], Never> { get }
    var reconfigureItemPublisher: AnyPublisher<ListItem, Never> { get }
    var addItemPublisher: AnyPublisher<ListItem, Never> { get }
    var deleteItemPublisher: AnyPublisher<ListItem.ID, Never> { get }
    
    func fetchData() -> ([ListSection], [ListItem])
    
    func bindToView(
        addItem: AnyPublisher<Void, Never>,
        deleteItem: AnyPublisher<ListItem.ID, Never>,
        searchTerm: AnyPublisher<String, Never>
    )
}



