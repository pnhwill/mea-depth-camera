//
//  HeaderTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 11/5/21.
//

import UIKit

class HeaderTextCell: ItemListCell<ListItem> {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListItem else { return }
        var content: UIListContentConfiguration = self.defaultContentConfiguration().updated(for: state)
        if item.title.isEmpty {
            content.text = item.subtitle
        } else {
            content.text = item.title
            content.textProperties.font = content.textProperties.font.bold
        }
        content.image = item.image
        contentConfiguration = content
    }
}
