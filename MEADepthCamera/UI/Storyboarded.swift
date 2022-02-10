//
//  Storyboarded.swift
//  MEADepthCamera
//
//  Created by Will on 1/31/22.
//

import UIKit

protocol Storyboarded {
    static var storyboardIdentifier: String { get }
}

extension Storyboarded where Self: UIViewController {
    static var storyboardIdentifier: String {
        String(describing: self)
    }
}

extension UIViewController: Storyboarded {}
