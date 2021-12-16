//
//  UIKit+Convenience.swift
//  MEADepthCamera
//
//  Created by Will on 12/8/21.
//

import UIKit

// MARK: UIViewController
extension UIViewController {
    
    enum StoryboardName {
        static let taskList = "TaskList"
        static let camera = "Camera"
    }
    
    enum StoryboardID {
        static let cameraNavController = "CameraNavigationController"
        static let taskListVC = "TaskListVC"
        static let taskDetailVC = "TaskDetailVC"
    }
    
    enum SegueID {
        static let showProcessingListSegueIdentifier = "ShowProcessingListSegue"
    }
    
    func setRootViewController(_ newRootViewController: UIViewController, animated: Bool) {
        guard let window = view.window else {
            assertionFailure("current VC has no window.")
            return
        }
        let transition: UIView.AnimationOptions = .transitionFlipFromRight
        if animated {
            UIView.transition(
                with: window,
                duration: 0.3,
                options: transition,
                animations: {
                    window.rootViewController = newRootViewController
                },
                completion: nil)
        } else {
            window.rootViewController = newRootViewController
        }
    }
    
    func alert(title: String, message: String, actions: [UIAlertAction]) {
        
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        
        actions.forEach {
            alertController.addAction($0)
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    func alert(alertController: UIAlertController) {
        // Append message to existing alert if present
        if let currentAlert = presentedViewController as? UIAlertController {
            currentAlert.message = (currentAlert.message ?? "") + "\n\n\(alertController.message ?? "")"
            return
        }
        present(alertController, animated: true, completion: nil)
    }
}

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

// MARK: UIFont
extension UIFont {
    
    var bold: UIFont {
        return with(.traitBold)
    }

    var italic: UIFont {
        return with(.traitItalic)
    }

    var boldItalic: UIFont {
        return with([.traitBold, .traitItalic])
    }
    
    func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(self.fontDescriptor.symbolicTraits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }

    func without(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(self.fontDescriptor.symbolicTraits.subtracting(UIFontDescriptor.SymbolicTraits(traits))) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}


