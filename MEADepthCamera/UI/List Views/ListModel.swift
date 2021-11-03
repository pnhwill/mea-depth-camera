//
//  ListModel.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/27/21.
//

import Foundation

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
struct ListItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var subTitle: String?
    var bodyText: [String]
}
