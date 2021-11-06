//
//  ItemListCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit

/// This list cell subclass is an abstract class with a property that holds the item the cell is displaying,
/// which is added to the cell's configuration state for subclasses to use when updating their configuration.
class ItemListCell: UICollectionViewListCell {
    
    private var item: ListItem? = nil
    
    func updateWithItem(_ newItem: ListItem) {
        guard item != newItem else { return }
        item = newItem
        setNeedsUpdateConfiguration()
    }
    
    override var configurationState: UICellConfigurationState {
        var state = super.configurationState
        state.item = self.item
        return state
    }
}

// Declare an extension on the cell state struct to provide a typed property for this custom state.
extension UICellConfigurationState {
    var item: ListItem? {
        set { self[.item] = newValue }
        get { return self[.item] as? ListItem }
    }
}

// Declare a custom key for a custom `item` property.
extension UIConfigurationStateCustomKey {
    static let item = UIConfigurationStateCustomKey("com.mea-lab.ItemListCell.item")
}









