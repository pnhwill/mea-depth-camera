//
//  HeaderTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 11/5/21.
//

import UIKit

/// Flexible `ItemListCell` subclass that changes behavior based on the content of the configuration state's `OldListItem` property.
///
/// For bold single-text headers: provide a `OldListItem` with a non-empty `title` string and a nil-valued `subtitle`.
/// For regular single-text cells: provide a `OldListItem` with an empty `title` string and a non-nil `subtitle`.
/// For dual-text value-configuration cells: provide a `OldListItem` with a non-empty `title` string and a non-nil `subtitle`.
class HeaderTextCell: ItemListCell<OldListItem> {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? OldListItem else { return }
        var content: UIListContentConfiguration = self.defaultContentConfiguration().updated(for: state)
        if item.title.isEmpty {
            content.text = item.subtitle
        } else {
            if let subtitle = item.subtitle {
                content = UIListContentConfiguration.valueCell().updated(for: state)
                content.secondaryText = subtitle
            } else {
                content.textProperties.font = content.textProperties.font.bold
            }
            content.text = item.title
        }
        content.image = item.image
        contentConfiguration = content
    }
}
