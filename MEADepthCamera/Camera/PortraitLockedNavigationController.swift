//
//  PortraitLockedNavigationController.swift
//  MEADepthCamera
//
//  Created by Will on 12/2/21.
//

import UIKit

/// UINavigationController subclass that ensures the interface stays locked in portrait orietentation.
///
/// We use this as a container for the CameraViewController, since it inherits its orientation from its parent.
class PortraitLockedNavigationController: UINavigationController {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        print("PortraitLockedNavigationController Initialized.")
//    }
//    
//    deinit {
//        print("PortraitLockedNavigationController deinitialized.")
//    }
}
