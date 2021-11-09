//
//  SessionSetupError.swift
//  MEADepthCamera
//
//  Created by Will on 11/9/21.
//

import Foundation

enum SessionSetupError: Error {
    case noVideoDevice
    case noAudioDevice
    case videoInputInitializationFailed(Error)
    case audioInputInitializationFailed(Error)
    case cannotAddVideoInput
    case cannotAddAudioInput
    case noIntrinsicMatrixDelivery
    case noVideoCaptureConnection
    case noAudioCaptureConnection
    case noDepthCaptureConnection
    case cannotAddVideoDataOutput
    case cannotAddAudioDataOutput
    case cannotAddDepthDataOutput
    case videoDeviceConfigurationFailed(Error)
    case noValidVideoFormat
    case noValidDepthFormat
    
}

extension SessionSetupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noVideoDevice:
            return NSLocalizedString("Could not find any video device.", comment: "")
        case .noAudioDevice:
            return NSLocalizedString("Could not find the microphone.", comment: "")
        case .videoInputInitializationFailed(let error):
            return NSLocalizedString("Could not create video device input: \(error.localizedDescription)", comment: "")
        case .audioInputInitializationFailed(let error):
            return NSLocalizedString("Could not create audio device input: \(error.localizedDescription)", comment: "")
        case .cannotAddVideoInput:
            return NSLocalizedString("Could not add video device input to the session.", comment: "")
        case .cannotAddAudioInput:
            return NSLocalizedString("Could not add audio device input to the session.", comment: "")
        case .noIntrinsicMatrixDelivery:
            return NSLocalizedString("Camera intrinsic matrix delivery not supported.", comment: "")
        case .noVideoCaptureConnection:
            return NSLocalizedString("No AVCaptureConnection for video data output.", comment: "")
        case .noAudioCaptureConnection:
            return NSLocalizedString("No AVCaptureConnection for audio data output.", comment: "")
        case .noDepthCaptureConnection:
            return NSLocalizedString("No AVCaptureConnection for depth data output.", comment: "")
        case .cannotAddVideoDataOutput:
            return NSLocalizedString("Could not add video data output to the session.", comment: "")
        case .cannotAddAudioDataOutput:
            return NSLocalizedString("Could not add audio data output to the session.", comment: "")
        case .cannotAddDepthDataOutput:
            return NSLocalizedString("Could not add depth data output to the session.", comment: "")
        case .videoDeviceConfigurationFailed(let error):
            return NSLocalizedString("Could not lock video device for configuration: \(error.localizedDescription)", comment: "")
        case .noValidVideoFormat:
            return NSLocalizedString("Failed to find valid video device format.", comment: "")
        case .noValidDepthFormat:
            return NSLocalizedString("Device does not support Float32 depth format.", comment: "")
        }
    }
}
