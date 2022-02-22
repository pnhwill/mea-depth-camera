//
//  ListTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/27/21.
//

import UIKit

/// View model for the `ListTextCell` collection view cell.
struct ListTextCellModel: Hashable {
    let title: String
    let bodyText: [String]
    
    init(listItem: ListItem) {
        title = listItem.title
        bodyText = listItem.bodyText
    }
    init(detailItem: DetailItem) {
        title = detailItem.title
        bodyText = detailItem.bodyText
    }
}

/// Custom `ItemListCell` subclass for displaying large title text with an arbitrary number of body text lines below.
class ListTextCell: ItemListCell<ListTextCellModel> {
    
    private var separatorConstraint: NSLayoutConstraint?
    
    // MARK: updateConfiguration(using:)
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListTextCellModel else { return }
        let content = TextCellContentConfiguration(
            titleText: item.title,
            bodyText: item.bodyText,
            titleContentConfiguration: .cell(),
            bodyContentConfiguration: .subtitleCell()
        ).updated(for: state)
        contentConfiguration = content
        updateSeparatorConstraint()
    }
}

extension ListTextCell {
    
    private func updateSeparatorConstraint() {
        guard let listContentView = contentView as? TextCellContentView,
              let textLayoutGuide = listContentView.titleView.textLayoutGuide else { return }
        if let existingConstraint = separatorConstraint, existingConstraint.isActive {
            return
        }
        let constraint = separatorLayoutGuide.leadingAnchor.constraint(equalTo: textLayoutGuide.leadingAnchor)
        constraint.isActive = true
        separatorConstraint = constraint
    }
}

