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

/// The delegate protocol for ItemListCell subclasses, to support interaction with the cell's item from within the cell.
protocol ItemListCellDelegate {
    /**
     Deletes the ListItem's stored NSManagedObject.
     
     When the user deletes a cell, the cell calls this method to notify the delegate (the list view model) to delete the item's object.
     */
    func delete(objectFor item: ListItem)
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











/*
class ListTextCell: ItemListCell {
    
    private var separatorConstraint: NSLayoutConstraint?
    
    func updateSeparatorConstraint() {
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
*/
