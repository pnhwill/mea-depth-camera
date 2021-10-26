//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import Foundation

protocol ListViewModel {
    associatedtype ListCell: ItemListCell
    associatedtype HeaderCell: ItemListCell
    
    var sectionsStore: AnyModelStore<ListSection>? { get }
    var itemsStore: AnyModelStore<ListItem>? { get }
}

struct ListSection: Identifiable {
    enum Identifier: Int, CaseIterable {
        case header
        case list
    }
    
    var id: Identifier
    var items: [ListItem.ID]?
}

struct ListItem: Identifiable, Hashable {
    var id: UUID
    var object: ModelObject
    
    init?(object: ModelObject) {
        guard let id = object.id else { return nil }
        self.object = object
        self.id = id
    }
    
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
