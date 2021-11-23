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
    var subtitleText: String?
    var bodyText: [String]
    var listContentConfiguration = UIListContentConfiguration.sidebarCell()
    var titleContentConfiguration = UIListContentConfiguration.sidebarHeader()
    
    func makeContentView() -> UIView & UIContentView {
        return TextCellContentView(configuration: self)
    }
    
    func updated(for state: UIConfigurationState) -> TextCellContentConfiguration {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfiguration = self
        updatedConfiguration.listContentConfiguration = listContentConfiguration.updated(for: state)
        updatedConfiguration.titleContentConfiguration = titleContentConfiguration.updated(for: state)
        return updatedConfiguration
    }
}

// MARK: TextCellContentView

class TextCellContentView: UIView, UIContentView {
    
    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? TextCellContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }
    
    private var appliedConfiguration: TextCellContentConfiguration!
    
    private(set) lazy var titleView = UIListContentView(configuration: defaultTitleContentConfiguration())
    private lazy var bodyView = LabelListView()
    
    init(configuration: TextCellContentConfiguration) {
        super.init(frame: .zero)
        setUpInternalViews()
        apply(configuration: configuration)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func defaultTitleContentConfiguration() -> UIListContentConfiguration {
        return .sidebarHeader()
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
            bodyView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
            bodyView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            bodyView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            bodyView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }
    
    private func apply(configuration: TextCellContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        
        var titleContent = configuration.titleContentConfiguration
        titleContent.text = configuration.titleText
        titleContent.secondaryText = configuration.subtitleText
        titleContent.axesPreservingSuperviewLayoutMargins = []
        titleContent.directionalLayoutMargins.bottom = 0
        titleView.configuration = titleContent
        
        let listConfiguration = configuration.listContentConfiguration
        var rowLabels: [UILabel] = []
        for rowText in configuration.bodyText {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = rowText
            label.font = listConfiguration.textProperties.font
            label.textColor = listConfiguration.textProperties.resolvedColor()
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 1
            rowLabels.append(label)
        }
        bodyView.directionalLayoutMargins = listConfiguration.directionalLayoutMargins
        bodyView.directionalLayoutMargins.top = 0
        bodyView.directionalLayoutMargins.bottom = titleContent.directionalLayoutMargins.top
        bodyView.labels = rowLabels
    }
}