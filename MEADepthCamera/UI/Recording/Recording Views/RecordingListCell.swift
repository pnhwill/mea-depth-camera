//
//  RecordingListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListCell: ItemListCell<RecordingListViewModel.Item> {
    
    private let frameCounterLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private lazy var listContentView = UIListContentView(configuration: defaultListContentConfiguration())
    private var customViewConstraints: (frameCounterLeading: NSLayoutConstraint,
                                        frameCounterTrailing: NSLayoutConstraint)?
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let item = state.item as? RecordingListViewModel.Item else { return }
        setUpViewsIfNeeded()
        
        // Configure the list content configuration and apply that to the list content view.
        var content = defaultListContentConfiguration().updated(for: state)
        content.text = item.name
        content.secondaryText = item.isProcessedText
        content.axesPreservingSuperviewLayoutMargins = []
        listContentView.configuration = content
        
        // Get the list value cell configuration for the current state, which we'll use to obtain the system default
        // styling and metrics to copy to our custom views.
        let valueConfiguration = UIListContentConfiguration.valueCell().updated(for: state)
        
        // Configure custom label for the category name, copying some of the styling from the value cell configuration.
        frameCounterLabel.text = item.frameCounterText
        frameCounterLabel.textColor = valueConfiguration.secondaryTextProperties.resolvedColor()
        frameCounterLabel.font = valueConfiguration.secondaryTextProperties.font
        frameCounterLabel.adjustsFontForContentSizeCategory = valueConfiguration.secondaryTextProperties.adjustsFontForContentSizeCategory
        
        // Update some of the constraints for our custom views using the system default metrics from the configurations.
        customViewConstraints?.frameCounterLeading.constant = content.directionalLayoutMargins.trailing
        customViewConstraints?.frameCounterLeading.constant = content.directionalLayoutMargins.trailing
        
        progressBar.isHidden = item.processedFrames != nil
        if let progress = item.progress {
            progressBar.setProgress(progress, animated: true)
        }
    }
}

extension RecordingListCell {
    private func defaultListContentConfiguration() -> UIListContentConfiguration { return .subtitleCell() }
    
    private func setUpViewsIfNeeded() {
        // We only need to do anything if we haven't already setup the views and created constraints.
        guard customViewConstraints == nil else { return }
        
        contentView.addSubview(listContentView)
        contentView.addSubview(frameCounterLabel)
        contentView.addSubview(progressBar)
        
        listContentView.translatesAutoresizingMaskIntoConstraints = false
        frameCounterLabel.translatesAutoresizingMaskIntoConstraints = false
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        
        let defaultHorizontalCompressionResistance = listContentView.contentCompressionResistancePriority(for: .horizontal)
        listContentView.setContentCompressionResistancePriority(defaultHorizontalCompressionResistance - 1, for: .horizontal)
        
        let constraints = (frameCounterLeading: frameCounterLabel.leadingAnchor.constraint(greaterThanOrEqualTo: listContentView.trailingAnchor),
                           frameCounterTrailing: contentView.trailingAnchor.constraint(equalTo: frameCounterLabel.trailingAnchor))
        
        NSLayoutConstraint.activate([
            listContentView.topAnchor.constraint(equalTo: contentView.topAnchor),
            listContentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            listContentView.bottomAnchor.constraint(equalTo: progressBar.topAnchor),
            progressBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: listContentView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            frameCounterLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            constraints.frameCounterLeading,
            constraints.frameCounterTrailing
        ])
        customViewConstraints = constraints
    }
}

