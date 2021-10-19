//
//  ItemListCell.swift
//  MEADepthCamera
//
//  Created by Will on 10/15/21.
//

import UIKit

// This list cell subclass is an abstract class with a property that holds the item the cell is displaying,
// which is added to the cell's configuration state for subclasses to use when updating their configuration.
class ItemListCell: UICollectionViewListCell {
    private var item: Item? = nil
    
    func updateWithItem(_ newItem: Item) {
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

// Declare a custom key for a custom `item` property.
extension UIConfigurationStateCustomKey {
    static let item = UIConfigurationStateCustomKey("com.mea-lab.ItemListCell.item")
}

// Declare an extension on the cell state struct to provide a typed property for this custom state.
extension UICellConfigurationState {
    var item: Item? {
        set { self[.item] = newValue }
        get { return self[.item] as? Item }
    }
}

class ListCell: ItemListCell {
    
//    func defaultListContentConfiguration() -> UIListContentConfiguration { return .subtitleCell() }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        
//        let object = state.item?.object
//
//        guard let objectType = object.type else { return }
        //let content =
//        self.contentConfiguration = content
        
        
        
        
    }
}

struct ListContentConfiguration: UIContentConfiguration, Hashable {
    
    var titleText: String
    var bodyText: [String]
    var buttonConfigurations: [UIButton.Configuration]
    
    func makeContentView() -> UIView & UIContentView {
        return DynamicListContentView(configuration: self)
    }
    
    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else { return self }
        print(state)
        // change things depending on type of state.item.object
        
        return self
    }
}

class DynamicListContentView: UIView, UIContentView {
    
    var stackView: ReadjustingStackView?
    var labels: [UILabel]?
    var buttons: [UIButton]?
    
    init(configuration: ListContentConfiguration) {
        super.init(frame: .zero)
        setupInternalViews()
        apply(configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func defaultListContentConfiguration() -> UIListContentConfiguration { return .subtitleCell() }
    
    func configure() {
        // To enable our button labels to automatically adjust to dynamic type settings changes,
        // we have to set `adjustsFontForContentSizeCategory` to `true`.
        buttons?.forEach { button in
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        
        labels?.forEach { label in
            label.adjustsFontForContentSizeCategory = true
        }
    }
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? ListContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }
    
    private let imageView = UIImageView()
    
    private func setupInternalViews() {
        
    }
    
    private var appliedConfiguration: ListContentConfiguration!
    
    private func apply(configuration: ListContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        
        
        
        
        
    }
}

class HeaderCell: ItemListCell {
    
}
