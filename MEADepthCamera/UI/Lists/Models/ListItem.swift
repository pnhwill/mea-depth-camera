//
//  ListModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/20/22.
//

import Foundation

/// A generic model of an item contained in a list cell with title text, optional subtitle text, and body text with an arbitrary number of lines.
struct ListItem: Identifiable, Hashable {
    var id: UUID
    var title: String
//    var subtitle: String?
    var bodyText: [String]
    
    init(id: UUID,
         title: String,
//         subTitle: String? = nil,
         bodyText: [String] = []) {
        self.id = id
        self.title = title
//        self.subtitle = subTitle
        self.bodyText = bodyText
    }
}

protocol ListItemRepresentable {
    var listItem: ListItem { get }
}
