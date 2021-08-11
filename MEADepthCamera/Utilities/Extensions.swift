//
//  Extensions.swift
//  MEADepthCamera
//
//  Created by Will on 7/23/21.
//

import AVFoundation
import UIKit

// MARK: UIViewController
extension UIViewController {
    func alert(title: String, message: String, actions: [UIAlertAction]) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        
        actions.forEach {
            alertController.addAction($0)
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: CGPoint
extension CGPoint {
    // Method to clamp a CGPoint within a certain bounds
    mutating func clamp(bounds: CGSize) {
        self.x = min(bounds.width, max(self.x, 0.0))
        self.y = min(bounds.height, max(self.y, 0.0))
    }
}

// MARK: CGSize
extension CGSize {
    func rounded() -> CGSize {
        return CGSize(width: self.width.rounded(), height: self.height.rounded())
    }
}

// MARK: Bundle
extension Bundle {
    // Use bundle name instead of hard-coding app name in alerts
    var applicationName: String {
        if let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return name
        } else if let name = object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return "-"
    }
}

// MARK: AVCaptureVideoOrientation
extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
    
    func angleOffsetFromPortraitOrientation(at position: AVCaptureDevice.Position) -> Double {
        switch self {
        case .portrait:
            return position == .front ? .pi : 0
        case .portraitUpsideDown:
            return position == .front ? 0 : .pi
        case .landscapeRight:
            return -.pi / 2.0
        case .landscapeLeft:
            return .pi / 2.0
        default:
            return 0
        }
    }
}

// MARK: AVCaptureConnection
extension AVCaptureConnection {
    func videoOrientationTransform(relativeTo destinationVideoOrientation: AVCaptureVideoOrientation) -> CGAffineTransform {
        let videoDevice: AVCaptureDevice
        if let deviceInput = inputPorts.first?.input as? AVCaptureDeviceInput, deviceInput.device.hasMediaType(.video) {
            videoDevice = deviceInput.device
        } else {
            // Fatal error? Programmer error?
            print("Video data output's video connection does not have a video device")
            return .identity
        }
        
        let fromAngleOffset = videoOrientation.angleOffsetFromPortraitOrientation(at: videoDevice.position)
        let toAngleOffset = destinationVideoOrientation.angleOffsetFromPortraitOrientation(at: videoDevice.position)
        let angleOffset = CGFloat(toAngleOffset - fromAngleOffset)
        let transform = CGAffineTransform(rotationAngle: angleOffset)
        
        return transform
    }
}

// MARK: AVCaptureSession.InterruptionReason
extension AVCaptureSession.InterruptionReason: CustomStringConvertible {
    public var description: String {
        var descriptionString = ""
        
        switch self {
        case .videoDeviceNotAvailableInBackground:
            descriptionString = "video device is not available in the background"
        case .audioDeviceInUseByAnotherClient:
            descriptionString = "audio device is in use by another client"
        case .videoDeviceInUseByAnotherClient:
            descriptionString = "video device is in use by another client"
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            descriptionString = "video device is not available with multiple foreground apps"
        case .videoDeviceNotAvailableDueToSystemPressure:
            descriptionString = "video device is not available due to system pressure"
        @unknown default:
            descriptionString = "unknown (\(self.rawValue)"
        }
        
        return descriptionString
    }
}

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
                
            default: return nil
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
                
            default: return nil
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
                
            default: return nil
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
                
            default: return nil
            }
        @unknown default:
            fatalError("Unknown orientation. Can't continue.")
        }
    }
}

// MARK: VisionFaceDetectionProcessor
extension LiveFaceDetectionProcessor {
    // Helper Methods for Handling Device Orientation & EXIF
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}

// MARK: ProcessInfo.ThermalState
extension ProcessInfo.ThermalState {
    var thermalStateString: String {
        let state = self
        var thermalStateString = "UNKNOWN"
        if state == .nominal {
            thermalStateString = "NOMINAL"
        } else if state == .fair {
            thermalStateString = "FAIR"
        } else if state == .serious {
            thermalStateString = "SERIOUS"
        } else if state == .critical {
            thermalStateString = "CRITICAL"
        }
        return thermalStateString
    }
}

// MARK: AVCaptureDevice.SystemPressureState
extension AVCaptureDevice.SystemPressureState {
    var pressureLevelString: String {
        let pressureLevel = self.level
        var pressureLevelString = "UNKNOWN"
        if pressureLevel == .nominal {
            pressureLevelString = "NOMINAL"
        } else if pressureLevel == .fair {
            pressureLevelString = "FAIR"
        } else if pressureLevel == .serious {
            pressureLevelString = "SERIOUS"
        } else if pressureLevel == .critical {
            pressureLevelString = "CRITICAL"
        } else if pressureLevel == .shutdown {
            print("Session stopped running due to shutdown system pressure level.")
            pressureLevelString = "SHUTDOWN"
        }
        return pressureLevelString
    }
}
