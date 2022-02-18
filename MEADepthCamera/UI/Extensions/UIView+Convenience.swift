//
//  UIView+Convenience.swift
//  MEADepthCamera
//
//  Created by Will on 2/16/22.
//

import UIKit

// MARK: UIView

extension UIView {
    
    func bindEdgesToSuperview() {
        guard let s = superview else {
            preconditionFailure("`superview` nil in bindEdgesToSuperview")
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        leadingAnchor.constraint(equalTo: s.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: s.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: s.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: s.bottomAnchor).isActive = true
    }
}
