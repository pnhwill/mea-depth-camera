//
//  AVFoundation+Extensions.swift
//  MEADepthCamera
//
//  Created by Will on 11/9/21.
//

import AVFoundation
import UIKit

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
