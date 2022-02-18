//
//  ListTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 1/21/22.
//

import UIKit

class ListTextCell: ItemListCell<ListItem> {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListItem else { return }
        var content = defaultContentConfiguration().updated(for: state)
        content.text = item.title
//        content.secondaryText = item.subtitle
        contentConfiguration = content
    }
}

