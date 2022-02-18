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
        static let main = "Main"
        static let taskList = "TaskList"
        static let camera = "Camera"
    }
    
    enum StoryboardID {
        static let aboutViewController = "AboutViewController"
        static let cameraNavController = "CameraNavigationController"
        static let cameraViewController = "CameraViewController"
        static let taskListVC = "TaskListVC"
        static let taskPlanDetailVC = "TaskPlanDetailVC"
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






