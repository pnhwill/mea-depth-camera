//
//  ListModel.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/27/21.
//

import Foundation
import CoreData

// MARK: ListSection
struct ListSection: Identifiable {
    enum Identifier: Int, CaseIterable {
        case header
        case list
    }
    
    var id: Identifier
    var items: [ListItem.ID]?
}

// MARK: ListItem
/// A generic model of an item contained in a list cell, providing value semantics and erasing the underlying type of the stored object.
struct ListItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var subTitle: String?
    var bodyText: [String]
//    var object: ModelObject
    
//    init?(object: ModelObject) {
//        guard let id = object.id else { return nil }
//        self.object = object
//        self.id = id
//    }
    
//    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
//        return lhs.id == rhs.id /*&& lhs.object == rhs.object*/
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
////        hasher.combine(object)
//    }
}
