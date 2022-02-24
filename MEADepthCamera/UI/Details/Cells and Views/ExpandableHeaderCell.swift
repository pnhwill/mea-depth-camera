//
//  ExpandableHeaderCell.swift
//  MEADepthCamera
//
//  Created by Will on 11/5/21.
//

import UIKit

/// ItemListCell subclass for expandable outline headers.
class ExpandableHeaderCell: ItemListCell<DetailItem> {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAccessories()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? DetailItem else { return }
        var content = defaultContentConfiguration().updated(for: state)
        content.text = item.title
        contentConfiguration = content
    }
}

extension ExpandableHeaderCell {
    
    private func configureAccessories() {
        let outlineDisclosure = UICellAccessory.outlineDisclosure()
        accessories = [outlineDisclosure]
    }
}
