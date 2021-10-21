//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import CoreData
import UIKit

protocol ListViewModel: UISearchResultsUpdating {
    
    associatedtype ListCell: ItemListCell
    associatedtype HeaderCell: ItemListCell
    
    var navigationTitle: String { get set }
    
    var sectionsStore: AnyModelStore<Section>? { get }
    var itemsStore: AnyModelStore<Item>? { get }
    
}

struct Section: Identifiable {
    
    enum Identifier: Int, CaseIterable {
        case header
        case list
    }
    
    var id: Identifier
    var items: [Item.ID]?
}

struct Item: Identifiable, Equatable, Hashable {

    var id: UUID
    var object: ModelObject
    
    init?(object: ModelObject) {
        guard let id = object.id else { return nil }
        self.object = object
        self.id = id
    }
    
    static func == (lhs: Item, rhs: Item) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
