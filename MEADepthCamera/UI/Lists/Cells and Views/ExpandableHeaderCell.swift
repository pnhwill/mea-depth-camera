//
//  ExpandableHeaderCell.swift
//  MEADepthCamera
//
//  Created by Will on 11/5/21.
//

import UIKit

class ExpandableHeaderCell: ItemListCell<ListItem> {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAccessories()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListItem else { return }
        var content = defaultListContentConfiguration().updated(for: state)
        content.text = item.title
        contentConfiguration = content
    }
}

extension ExpandableHeaderCell {
    private func defaultListContentConfiguration() -> UIListContentConfiguration { return .sidebarHeader() }
    
    private func configureAccessories() {
        let outlineDisclosure = UICellAccessory.outlineDisclosure()
        accessories = [outlineDisclosure]
    }
}
