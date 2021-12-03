//
//  PortraitLockedNavigationController.swift
//  MEADepthCamera
//
//  Created by Will on 12/2/21.
//

import UIKit

/// UINavigationController subclass that stays locked in portrait orientation.
///
/// We use this as a container for the CameraViewController, since it inherits its orientation from its parent.
class PortraitLockedNavigationController: UINavigationController {
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    override var shouldAutorotate: Bool {
        return false
    }
}
