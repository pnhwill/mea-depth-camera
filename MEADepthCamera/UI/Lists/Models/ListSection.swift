//
//  ListSection.swift
//  MEADepthCamera
//
//  Created by Will on 2/7/22.
//

import Foundation

/// Generic model of a section in a list of items, containing an array of the item identifiers for that section.
struct ListSection: Identifiable {
    var id: String
    var items: [ListItem.ID]
    var canDelete: Bool
}

protocol ListSectionRepresentable {
    var listSection: ListSection { get }
}
