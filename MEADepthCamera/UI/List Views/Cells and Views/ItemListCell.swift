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








class ListTextCell: ItemListCell {
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        
        
        
    }
    
    
    
    
}














struct StackListContentConfiguration: UIContentConfiguration, Equatable {
    
    var subContent: [UIContentConfiguration]
    var isStackViewDynamic: Bool = true
    var stackViewAxis: NSLayoutConstraint.Axis = .horizontal
    
    private let identifier = UUID()
    
    static func == (lhs: StackListContentConfiguration, rhs: StackListContentConfiguration) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func makeContentView() -> UIView & UIContentView {
        if subContent.count == 1 {
            return subContent[0].makeContentView()
        } else {
            return StackListContentView(configuration: self)
        }
    }
    
    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self
        updatedConfiguration.subContent = subContent.map { $0.updated(for: state) }
        return updatedConfiguration
    }
}

class StackListContentView: UIView, UIContentView {
    
    private lazy var stackView = ReadjustingStackView()
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? StackListContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }
    
    private var appliedConfiguration: StackListContentConfiguration!
    
    init(configuration: StackListContentConfiguration) {
        super.init(frame: .zero)
        setupInternalViews()
        apply(configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupInternalViews() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }
    
    private func apply(configuration: StackListContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        
        for config in configuration.subContent {
            let newView = config.makeContentView()
            
//            newView.translatesAutoresizingMaskIntoConstraints = false
//
//            if let listContentView = newView as? UIListContentView {
//                guard let textLayoutGuide = listContentView.textLayoutGuide else { fatalError() }
//
//                NSLayoutConstraint.activate([
//                    listContentView.heightAnchor.constraint(equalTo: textLayoutGuide.heightAnchor)
//                ])
//            }
            
            

            stackView.addArrangedSubview(newView)
        }
        stackView.readjustingEnabled = configuration.isStackViewDynamic
        stackView.desiredAxis = configuration.stackViewAxis
//        stackView.isHidden = false
    }
}
/*
protocol DynamicContentConfiguration: UIContentConfiguration, Hashable {

    associatedtype SubContent: UIContentConfiguration & Hashable
    
    var subContent: [SubContent] { get set }
    var isStackViewDynamic: Bool { get set }
    var stackViewAxis: NSLayoutConstraint.Axis { get set }
}

extension DynamicContentConfiguration {
    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self
        updatedConfiguration.subContent = subContent.map { $0.updated(for: state) }
        return updatedConfiguration
    }
}

struct ListContentConfiguration: DynamicContentConfiguration {
    
    var subContent: [UIListContentConfiguration]
    var isStackViewDynamic: Bool = false
    var stackViewAxis: NSLayoutConstraint.Axis = .vertical
    
    func makeContentView() -> UIView & UIContentView {
        if subContent.count == 1 {
            return UIListContentView(configuration: subContent[0])
        } else {
            return DynamicListContentView(configuration: self)
        }
    }
}

struct CompositionalContentConfiguration: DynamicContentConfiguration {
    
    var subContent: [CompositionalContentConfiguration]
    var isStackViewDynamic: Bool = true
    var stackViewAxis: NSLayoutConstraint.Axis = .horizontal
    
    func makeContentView() -> UIView & UIContentView {
        if subContent.count == 1 {
            return subContent[0].makeContentView()
        } else {
            return DynamicListContentView(configuration: self)
        }
    }
}

class DynamicListContentView<T: DynamicContentConfiguration>: UIView, UIContentView {
    
    var stackView = ReadjustingStackView()
    
    init(configuration: T) {
        super.init(frame: .zero)
        setupInternalViews()
        apply(configuration: configuration)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func defaultListContentConfiguration() -> UIListContentConfiguration { return .subtitleCell() }
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? T else { return }
            apply(configuration: newConfig)
        }
    }
    
    private func setupInternalViews() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
        stackView.isHidden = true
    }
    
    private var appliedConfiguration: T!
    
    private func apply(configuration: T) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        
        for config in configuration.subContent {
            let newView = config.makeContentView()
            stackView.addArrangedSubview(newView)
        }
        stackView.readjustingEnabled = configuration.isStackViewDynamic
        stackView.desiredAxis = configuration.stackViewAxis
    }
}
*/



/*

struct CompositionalConfigurationEnum: UIContentConfiguration, Hashable {

    enum SubContent: Hashable {
        case stack([CompositionalConfiguration])
        case list(UIListContentConfiguration)
    }

//    var content:
    var subContent: SubContent
    var isStackViewDynamic: Bool = false
    var stackViewAxis: NSLayoutConstraint.Axis = .horizontal

    func makeContentView() -> UIView & UIContentView {
        switch subContent {
        case .stack(let a):
            return DynamicListContentView(configuration: a[0])
        case .list(let uIListContentConfiguration):
            return UIListContentView(configuration: uIListContentConfiguration)
        }
    }

    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self
        switch subContent {
        case .stack(let array):
            updatedConfiguration.subContent = SubContent.stack(array.map{ $0.updated(for: state) })
        case .list(let uIListContentConfiguration):
            updatedConfiguration.subContent = SubContent.list(uIListContentConfiguration.updated(for: state))
        }
        return updatedConfiguration
    }
}



struct CompositionalConfiguration: UIContentConfiguration, Hashable {

    var subContent: [CompositionalConfiguration]
    var listContent: UIListContentConfiguration
    var listContentFirst: Bool = true
    var isStackViewDynamic: Bool = false
    var stackViewAxis: NSLayoutConstraint.Axis = .horizontal
    
    func makeContentView() -> UIView & UIContentView {
        return DynamicListContentView(configuration: self)
    }
    
    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self

        return updatedConfiguration
    }
}


//struct ListContentConfiguration: UIContentConfiguration, Hashable {
//
//    enum ContentType: Hashable {
//        case dynamic([ListContentConfiguration])
//        case stack([ListContentConfiguration])
//        case title(UIListContentConfiguration)
//        case body(UIListContentConfiguration)
//    }
//
//    var contentType: ContentType?
//
//    private(set) var subContent: [ListContentConfiguration]
//    private(set) var finalContent: UIListContentConfiguration?
//    var finalContentFirst: Bool = true
//    var isStackViewDynamic: Bool = false
//    var stackViewAxis: NSLayoutConstraint.Axis = .horizontal
//
////    var titleConfiguration: UIListContentConfiguration
////    var bodyConfigurations: [[UIListContentConfiguration]]
//
//    init(subContent: [ListContentConfiguration] = [], finalContent: UIListContentConfiguration? = nil) {
//        self.subContent = subContent
//        self.finalContent = finalContent
//    }
//
//    func makeContentView() -> UIView & UIContentView {
////        var contentViews
//        let contentViews = subContent.map { DynamicListContentView(configuration: $0) }
//        if let finalContent = finalContent {
////            contentViews.append(UIListContentView(configuration: finalContent))
//        }
////        let finalContentView =
//
//        return DynamicListContentView(configuration: self)
//    }
//
//    func updated(for state: UIConfigurationState) -> Self {
//        guard let state = state as? UICellConfigurationState else { return self }
//        var updatedConfiguration = self
//        // Update subconfigurations
//        updatedConfiguration.subContent = subContent.map { $0.updated(for: state) }
//        updatedConfiguration.finalContent = finalContent?.updated(for: state)
////        updatedConfiguration.titleConfiguration = titleConfiguration.updated(for: state)
////        updatedConfiguration.bodyConfigurations = bodyConfigurations.map { $0.map { $0.updated(for: state) } }
//        return updatedConfiguration
//    }
//}

//protocol StackListContentConfiguration: UIContentConfiguration, Hashable {
//
//    var titleConfiguration: UIListContentConfiguration { get }
//    var bodyConfiguration: [[UIListContentConfiguration]] { get }
//    var buttonConfiguration: [UIButton.Configuration] { get }
//
//}

class DynamicListContentView: UIView, UIContentView {
    
    var stackView = ReadjustingStackView()
//    private lazy var stackView = ReadjustingStackView(frame: .zero)
//    var labels: [UILabel]?
//    var buttons: [UIButton]?
    
    init(configuration: CompositionalConfiguration) {
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
//        buttons?.forEach { button in
//            button.titleLabel?.adjustsFontForContentSizeCategory = true
//        }
//
//        labels?.forEach { label in
//            label.adjustsFontForContentSizeCategory = true
//        }
    }
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? CompositionalConfiguration else { return }
            apply(configuration: newConfig)
        }
    }
    
    private func makeStackView(for configuration: CompositionalConfiguration) -> UIStackView {
        var subViews: [UIView & UIContentView] = configuration.subContent.map { DynamicListContentView(configuration: $0) }
        let listViews = UIListContentView(configuration: configuration.listContent)
//        if configuration.listContentFirst {
//            subViews.insert(contentsOf: listViews, at: 0)
//        } else {
//            subViews.append(contentsOf: listViews)
//        }
        
        var stackView: UIStackView
        if configuration.isStackViewDynamic {
            stackView = ReadjustingStackView(arrangedSubviews: subViews)
        } else {
            stackView = UIStackView(arrangedSubviews: subViews)
        }
        return stackView
    }
    
    private func setupInternalViews() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
        stackView.isHidden = true
    }
    
    private var appliedConfiguration: CompositionalConfiguration!
    
    private func apply(configuration: CompositionalConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
    }
}
*/
class HeaderCell: ItemListCell {
    
}

