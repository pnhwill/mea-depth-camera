//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import CoreData
import UIKit

protocol ListViewModel: UISearchResultsUpdating {
    
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
    static func == (lhs: Item, rhs: Item) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id: UUID?
    var object: ModelObject
}
