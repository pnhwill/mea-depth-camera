//
//  ListTextCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/27/21.
//

import UIKit

/// The delegate protocol for ListTextCells, to support interaction with the cell's item from within the cell.
protocol ListTextCellDelegate: AnyObject {
    /**
     Deletes the ListItem's stored NSManagedObject.
     
     When the user deletes a cell, the cell calls this method to notify the delegate (the list view model) to delete the item's object.
     */
    func delete(objectFor item: ListItem)
}

class ListTextCell: ItemListCell<ListItem> {
    
    weak var delegate: ListTextCellDelegate?
    
    private var separatorConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAccessories()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: updateConfiguration(using:)
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? ListItem else { return }
        let content = TextCellContentConfiguration(titleText: item.title, subtitleText: item.subtitle, bodyText: item.bodyText).updated(for: state)
        contentConfiguration = content
        updateSeparatorConstraint()
    }
}

extension ListTextCell {
    private func configureAccessories() {
        let disclosure = UICellAccessory.disclosureIndicator()
        let delete = UICellAccessory.delete() { self.deleteAction() }
        accessories = [delete, disclosure]
    }
    
    private func deleteAction() {
        guard let item = configurationState.item as? ListItem else { return }
        delegate?.delete(objectFor: item)
    }
    
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