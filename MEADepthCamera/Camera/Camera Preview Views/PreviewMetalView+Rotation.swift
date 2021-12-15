//
//  PreviewMetalView+Rotation.swift
//  MEADepthCamera
//
//  Created by Will on 11/9/21.
//

import AVFoundation
import UIKit

// MARK: PreviewMetalView.Rotation
extension PreviewMetalView.Rotation {
    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevice.Position) {
        /*
         Calculate the rotation between the videoOrientation and the interfaceOrientation.
         The direction of the rotation depends upon the camera position.
         */
        switch videoOrientation {
            
        case .portrait:
            switch interfaceOrientation {
            case .landscapeRight:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
            case .landscapeLeft:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
            case .portrait:
                self = .rotate0Degrees
            case .portraitUpsideDown:
                self = .rotate180Degrees
            default:
                return nil
            }
            
        case .portraitUpsideDown:
            switch interfaceOrientation {
            case .landscapeRight:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
            case .landscapeLeft:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
            case .portrait:
                self = .rotate180Degrees
            case .portraitUpsideDown:
                self = .rotate0Degrees
            default:
                return nil
            }
            
        case .landscapeRight:
            switch interfaceOrientation {
            case .landscapeRight:
                self = .rotate0Degrees
            case .landscapeLeft:
                self = .rotate180Degrees
            case .portrait:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
            case .portraitUpsideDown:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
            default:
                return nil
            }
            
        case .landscapeLeft:
            switch interfaceOrientation {
            case .landscapeLeft:
                self = .rotate0Degrees
            case .landscapeRight:
                self = .rotate180Degrees
            case .portrait:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
            case .portraitUpsideDown:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
            default:
                return nil
            }
        @unknown default:
            fatalError("Unknown orientation. Can't continue.")
        }
    }
}
