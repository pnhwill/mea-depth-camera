//
//  Alert.swift
//  MEADepthCamera
//
//  Created by Will on 12/9/21.
//

import UIKit

/// A structure that displays an alert controller.
struct Alert {
    
    /// Displays an error message in an alert with an "OK" action.
    static func displayError(message: String, completion: (() -> Void)?) -> UIAlertController {
        let action = UIAlertAction(title: "OK", style: .cancel) { _ in
            completion?()
        }
        let alertController = UIAlertController(title: Bundle.main.applicationName,
                                                message: message,
                                                preferredStyle: .alert)
        alertController.addAction(action)
        
        return alertController
    }
    
//    static func confirmDelete(of item: OldListItem, completion: ((Bool) -> Void)?) -> UIAlertController? {
//        return nil
//    }
    
}
