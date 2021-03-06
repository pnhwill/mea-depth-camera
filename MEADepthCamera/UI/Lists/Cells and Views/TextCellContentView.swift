//
//  TextCellContentView.swift
//  MEADepthCamera
//
//  Created by Will on 10/22/21.
//

import UIKit

// MARK: TextCellContentConfiguration
/// Custom content configuration that can be used with any cell, containing large title text with a list of smaller body text below.
struct TextCellContentConfiguration: UIContentConfiguration, Hashable {
    
    var titleText: String
    var bodyText: [String]
    var defaultContentConfiguration: UIListContentConfiguration
    
    func makeContentView() -> UIView & UIContentView {
        return TextCellContentView(configuration: self)
    }
    
    func updated(for state: UIConfigurationState) -> TextCellContentConfiguration {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self
        updatedConfiguration.defaultContentConfiguration = defaultContentConfiguration.updated(for: state)
        return updatedConfiguration
    }
}

// MARK: TextCellContentView
/// Custom `UIContentView` that displays large title text with a list of smaller body text below.
final class TextCellContentView: UIView, UIContentView {
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? TextCellContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }
    
    private var appliedConfiguration: TextCellContentConfiguration!
    
    private(set) var titleView: UIListContentView!
    private lazy var bodyView = LabelListView()
    
    init(configuration: TextCellContentConfiguration) {
        super.init(frame: .zero)
        titleView = UIListContentView(configuration: configuration.defaultContentConfiguration)
        setUpInternalViews()
        apply(configuration: configuration)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpInternalViews() {
        directionalLayoutMargins = .zero
        
        addSubview(titleView)
        addSubview(bodyView)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            titleView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            titleView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
//            bodyView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
            bodyView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            bodyView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            bodyView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
        ])
        
    }
    
    private func apply(configuration: TextCellContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        
        var titleContent = configuration.defaultContentConfiguration
        titleContent.axesPreservingSuperviewLayoutMargins = []
        titleContent.text = configuration.titleText
        
        // Check if configuration contains body text and set up body labels, otherwise remove the body view.
        if !configuration.bodyText.isEmpty {
            titleContent.directionalLayoutMargins.bottom = 0
            
            var bodyContent = configuration.defaultContentConfiguration
            bodyContent.axesPreservingSuperviewLayoutMargins = []
            bodyContent.directionalLayoutMargins.top = 0
            bodyView.directionalLayoutMargins = bodyContent.directionalLayoutMargins
            
            var rowLabels: [UILabel] = []
            for rowText in configuration.bodyText {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.text = rowText
                label.font = bodyContent.secondaryTextProperties.font
                label.textColor = bodyContent.secondaryTextProperties.resolvedColor()
                label.adjustsFontForContentSizeCategory = true
                label.numberOfLines = 1
                rowLabels.append(label)
            }
            bodyView.labels = rowLabels
            bodyView.topAnchor.constraint(equalToSystemSpacingBelow: titleView.bottomAnchor, multiplier: 1).isActive = true
        } else {
            bodyView.removeFromSuperview()
            titleView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor).isActive = true
        }
        titleView.configuration = titleContent
    }
}
