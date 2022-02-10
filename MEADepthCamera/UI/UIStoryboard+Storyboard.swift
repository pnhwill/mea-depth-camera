//
//  UIStoryboard+Storyboard.swift
//  MEADepthCamera
//
//  Created by Will on 1/31/22.
//

import UIKit

extension UIStoryboard {
    
    enum Storyboard: String {
        case main
        
        var filename: String {
            rawValue.capitalized
        }
    }
    
    convenience init(storyboard: Storyboard, bundle: Bundle? = nil) {
        self.init(name: storyboard.filename, bundle: bundle)
    }
    
    func instantiateViewController<VC: UIViewController>() -> VC {
        guard let viewController = self.instantiateViewController(withIdentifier: VC.storyboardIdentifier) as? VC else {
            fatalError("Couldn't instantiate view controller with identifier \(VC.storyboardIdentifier).")
        }
        
        return viewController
    }
    
}
