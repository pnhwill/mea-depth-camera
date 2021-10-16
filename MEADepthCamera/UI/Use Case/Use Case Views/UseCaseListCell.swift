//
//  UseCaseListCell.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//

import UIKit

class NewUseCaseListCell: ListCell {
    
    static let reuseIdentifier = "UseCaseListCell"
    
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let subjectIDLabel = UILabel()
    private let experimentLabel = UILabel()
    private let recordedTasksCountLabel = UILabel()
    
    
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        
    }
}





class UseCaseListCell: UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var subjectIDLabel: UILabel!
    @IBOutlet weak var numRecordingsLabel: UILabel!
    
    func configure(title: String?, dateText: String?, subjectIDText: String?, recordingsCountText: String) {
        titleLabel.text = title
        dateLabel.text = dateText
        if let subjectIDText = subjectIDText {
            subjectIDLabel.text = "Subject ID: " + subjectIDText
        }
        numRecordingsLabel.text = recordingsCountText
    }
    
}




// MARK: ReadjustingStackView
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A custom stack view class that automatically adjusts its orientation as needed to fit the content inside without truncation.
*/

import UIKit

class ReadjustingStackView: UIStackView {
    
    // To know the size of our margins without hardcoding them, we have an outlet to a leading space constraint to read the constant value.
    /*@IBOutlet*/ var leadingConstraint: NSLayoutConstraint!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        // We want to recalculate our orientation whenever the dynamic type settings on the device change
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(adjustOrientation),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    // This takes care of recalculating our orientation whenever our content or layout changes
    // (such as due to device rotation, addition of more buttons to the stack view, etc).
    override func layoutSubviews() {
        adjustOrientation()
    }
    
    @objc
    func adjustOrientation() {
        // Always attempt to fit everything horizontally first
        axis = .horizontal
        alignment = .firstBaseline
        
        let desiredStackViewWidth = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        if let parent = superview {
            let availableWidth = parent.bounds.inset(by: parent.safeAreaInsets).width - (leadingConstraint.constant * 2.0)
            if desiredStackViewWidth > availableWidth {
                axis = .vertical
                alignment = .fill
            }
        }
    }
}
