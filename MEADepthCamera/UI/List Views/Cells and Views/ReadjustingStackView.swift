//
//  ReadjustingStackView.swift
//  MEADepthCamera
//
//  Created by Will on 10/19/21.
//
/*
Abstract:
A custom stack view class that automatically adjusts its orientation as needed to fit the content inside without truncation.
*/

import UIKit

class ReadjustingStackView: UIStackView {
    
    // The size of our margins.
    var marginSize: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // We want to recalculate our orientation whenever the dynamic type settings on the device change
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(adjustOrientation),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            let availableWidth = parent.bounds.inset(by: parent.safeAreaInsets).width - (marginSize * 2.0)
            if desiredStackViewWidth > availableWidth {
                axis = .vertical
                alignment = .fill
            }
        }
    }
}
