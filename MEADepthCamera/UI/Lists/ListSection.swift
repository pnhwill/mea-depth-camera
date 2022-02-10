//
//  ListSection.swift
//  MEADepthCamera
//
//  Created by Will on 2/7/22.
//

import Foundation

struct ListSection: Identifiable {
    var id: String
    var items: [ListItem.ID]
    var canDelete: Bool
}

protocol ListSectionRepresentable {
    var listSection: ListSection { get }
}
