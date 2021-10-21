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
    
    var marginSize: CGFloat = 0
    var readjustingEnabled: Bool = true
    var desiredAxis: NSLayoutConstraint.Axis = .horizontal
    
    private var desiredAlignment: UIStackView.Alignment {
        switch desiredAxis {
        case .horizontal:
            return .firstBaseline
        case .vertical:
            return .fill
        @unknown default:
            return .fill
        }
    }
    
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
        super.layoutSubviews()
        adjustOrientation()
    }
    
    @objc
    func adjustOrientation() {
        
        // Always attempt to fit everything horizontally first
        axis = desiredAxis
        alignment = desiredAlignment
        
        guard readjustingEnabled else { return }
        
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
