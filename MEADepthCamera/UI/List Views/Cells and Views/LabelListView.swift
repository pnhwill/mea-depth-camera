//
//  LabelListView.swift
//  MEADepthCamera
//
//  Created by Will on 10/22/21.
//

import UIKit

/// A custom view with an arbitrary number of labels.
class LabelListView: UIView {
    
    var labels: [UILabel] {
        didSet {
            if labels != oldValue {
                setUpLabelsAndConstraints()
            }
        }
    }
    
    init(labels: [UILabel]) {
        self.labels = labels
        super.init(frame: .zero)
        setUpLabelsAndConstraints()
    }
    
    convenience init() {
        self.init(labels: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Set up labels and constraints so that both fonts and spacing automatically adjusts when the content size changes.
     */
    private func setUpLabelsAndConstraints() {
        guard var currentLabel = labels.first else { return }
        addSubview(currentLabel)
        /*
         To have all labels extend the full width of the cell (within default margins); one label's leading and trailing anchors are constrained
         to the corresponding anchors of the view and each of the other labels is constrained to align its leading and trailing anchors with
         the first one.
         
         To achieve a layout that looks good at all content sizes, the spacing between elements should adjust along with the content.
         
         Since the appropriate spacing around text depends on properties of the font being used; the first baseline of the top label is
         constrained to use a system spacing to the top of the view, rather than a regular top-anchor to top-anchor constraint.
         
         Similarly, the _last_ baseline of the bottom label is constrained to use a system spacing to the bottom of the view, rather than
         a bottom-anchor to bottom-anchor constraint.
         
         Since any of the labels could wrap to multiple lines; the _last_ baseline of each label is constrained to use a system
         spacing to the _first_ baseline of the label below.
         */
        NSLayoutConstraint.activate([
            currentLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            currentLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            currentLabel.firstBaselineAnchor.constraint(equalToSystemSpacingBelow: layoutMarginsGuide.topAnchor, multiplier: 1)
        ])
        for label in labels[1...] {
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: currentLabel.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: currentLabel.trailingAnchor),
                label.firstBaselineAnchor.constraint(equalToSystemSpacingBelow: currentLabel.lastBaselineAnchor, multiplier: 1)
            ])
            currentLabel = label
        }
        layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: currentLabel.lastBaselineAnchor, multiplier: 1).isActive = true
    }
}

