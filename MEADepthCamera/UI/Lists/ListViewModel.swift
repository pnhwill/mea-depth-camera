//
//  ListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit

// MARK: ListViewModel
/// Protocol for ListViewController view models.
protocol ListViewModel {
    
    typealias Item = ListItem
    typealias Section = ListSection
    
    var sectionsStore: ObservableModelStore<ListSection>? { get }
    var itemsStore: ObservableModelStore<Item>? { get }    
}

// MARK: ListSection
/// Generic model of a list section for either a header or the main list of items, containing an array of the item identifiers for that section.
struct ListSection: Identifiable {
    enum Identifier: Int, CaseIterable {
        case header
        case list
    }
    
    var id: Identifier
    var items: [ListItem.ID]?
}

// MARK: ListItem
/// A generic model of an item contained in a list cell with title text, optional subtitle text, and body text with an arbitrary number of lines.
///
/// ListItem can be used to create expandable outline headers by setting the subItems property.
/// Only use subItems to store data for child cells in an outline, not to store additional data for the item's own cell.
struct ListItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var subtitle: String?
    var bodyText: [String]
    var image: UIImage?
    var subItems: [ListItem]
    
    init(id: UUID,
         title: String,
         subTitle: String? = nil,
         bodyText: [String] = [],
         image: UIImage? = nil,
         subItems: [ListItem] = []) {
        self.id = id
        self.title = title
        self.subtitle = subTitle
        self.bodyText = bodyText
        self.image = image
        self.subItems = subItems
    }
}


// MARK: - ListItemArrayConvertible
/// Protocol for types that can be converted into an array of ListItems.
protocol ListItemArrayConvertible {
    var listItems: [ListItem] { get }
}

//extension ListItemArrayConvertible where Self: DictionaryIdentifiable & CaseIterable {
//    var listItems: [ListItem] {
//        Self.allCases.map { ListItem(id: $0.id, title: ) }
//    }
//}

// MARK: IdentifiedListItemArrayConvertible
/// ListItemArrayConvertible types that use an associated Hashable type as an identifier.
protocol IdentifiedListItemArrayConvertible: ListItemArrayConvertible {
    associatedtype Item: Hashable
}

// MARK: SubtitleItemArrayConvertible
/// IdentifiedListItemArrayConvertible types that contain subtitle text in a dictionary using Item as keys.
protocol SubtitleItemArrayConvertible: IdentifiedListItemArrayConvertible {
    var subtitleText: [Item: String] { get }
}

extension SubtitleItemArrayConvertible where Item: Identifiable & RawRepresentable & CaseIterable, Item.ID == UUID, Item.RawValue == String {
    var listItems: [ListItem] {
        Item.allCases.map { ListItem(id: $0.id, title: $0.rawValue, subTitle: subtitleText[$0]) }
//        subtitleText.map { ListItem(id: $0.key.id, title: $0.key.rawValue, subTitle: $0.value) }
    }
}

// MARK: OutlineItemConvertible
/// IdentifiedListItemArrayConvertible types that contain ListItemArrayConvertible subitems in a dictionary using Item as keys.
protocol OutlineItemArrayConvertible: IdentifiedListItemArrayConvertible {
    var subItems: [Item: ListItemArrayConvertible] { get }
}

extension OutlineItemArrayConvertible where Item: Identifiable & RawRepresentable, Item.ID == UUID, Item.RawValue == String {
    var listItems: [ListItem] {
        subItems.map { ListItem(id: $0.key.id, title: $0.key.rawValue, subItems: $0.value.listItems) }
    }
}

// MARK: DictionaryIdentifiable
/// UUID Identifiable types that contain a static dictionary containing its identifiers.
protocol DictionaryIdentifiable: Identifiable, Hashable where ID == UUID {
    static var identifiers: [Self: UUID] { get }
}

extension DictionaryIdentifiable {
    var id: UUID { Self.identifiers[self]! }
}

extension DictionaryIdentifiable where Self: CaseIterable {
    static func newIdentifierDictionary() -> [Self: UUID] {
        return Dictionary(uniqueKeysWithValues: Self.allCases.map { ($0, UUID()) })
    }
}

