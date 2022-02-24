//
//  OldListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit

// MARK: DetailItem
/// A generic model of an item contained in a list cell with title text, optional subtitle text, and body text with an arbitrary number of lines.
///
/// DetailItem can be used to create expandable outline headers by setting the subItems property.
/// Only use subItems to store data for child cells in an outline, not to store additional data for the item's own cell.
struct DetailItem: Identifiable, Hashable {
    var id: UUID
    var title: String
//    var subtitle: String?
    var bodyText: [String]
    var image: UIImage?
    var subItems: [DetailItem]
    
    init(id: UUID,
         title: String,
//         subtitle: String? = nil,
         bodyText: [String] = [],
         image: UIImage? = nil,
         subItems: [DetailItem] = []) {
        self.id = id
        self.title = title
//        self.subtitle = subtitle
        self.bodyText = bodyText
        self.image = image
        self.subItems = subItems
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

