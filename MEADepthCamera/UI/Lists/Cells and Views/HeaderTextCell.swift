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
        var content: UIListContentConfiguration = self.defaultContentConfiguration()
        if item.title.isEmpty {
//            content = .sidebarCell()
            content.text = item.subtitle
        } else {
//            content = .sidebarHeader()
            content.text = item.title
        }
        contentConfiguration = content
    }
}
