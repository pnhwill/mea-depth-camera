//
//  ListModel.swift
//  MEADepthCamera
//
//  Created by Will on 1/20/22.
//

import Foundation
import UIKit

// MARK: ListItem

protocol ListItemRepresentable {
    var listItem: ListItem { get }
}

struct ListItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var subtitle: String?
    var bodyText: [String]
    
    init(id: UUID,
         title: String,
         subTitle: String? = nil,
         bodyText: [String] = []) {
        self.id = id
        self.title = title
        self.subtitle = subTitle
        self.bodyText = bodyText
    }
}



