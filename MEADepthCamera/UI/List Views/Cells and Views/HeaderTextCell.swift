//
//  HeaderTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 11/5/21.
//

import UIKit

class HeaderTextCell: ItemListCell {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item else { return }
        var content: UIListContentConfiguration
        if item.title.isEmpty, let subtitle = item.subtitle {
            content = .sidebarCell()
            content.text = subtitle
        } else {
            content = .sidebarHeader()
            content.text = item.title
        }
        contentConfiguration = content
    }
}
