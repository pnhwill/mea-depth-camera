//
//  ListModel.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/27/21.
//

import Foundation
import UIKit

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
