//
//  Enumerations.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation

enum OutputType: String, Codable {
    case video
    case audio
    case depth
    case landmarks2D
    case landmarks3D
    case info
    case frameIndex
}

enum WriteState {
    case inactive, active
}

enum FileWriteResult {
    case success
    case failed(Error?)
}

enum TrackingState {
    case tracking(Int)
    case stopped
}

enum FileWriterError: Error {
    case assetWriterCancelled
    case unknown
    
    static func getErrorForStatus(of assetWriter: AVAssetWriter) -> Self {
        switch assetWriter.status {
        case .cancelled:
            return .assetWriterCancelled
        default:
            return .unknown
        }
    }
}

extension FileWriterError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .assetWriterCancelled:
            return "AVAssetWriter cancelled writing"
        case .unknown:
            return "Unknown error occured"
        }
    }
}

enum VisionTrackerProcessorError: Error {
    case readerInitializationFailed
    case firstFrameReadFailed
    case faceTrackingFailed
    case faceRectangleDetectionFailed
}

extension VisionTrackerProcessorError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .readerInitializationFailed:
            return "Cannot create a Video Reader for selected video."
        case .firstFrameReadFailed:
            return "Cannot read the first frame from selected video."
        case .faceTrackingFailed:
            return "Tracking of detected face failed."
        case .faceRectangleDetectionFailed:
            return " Face Rectangle Detector failed to detect face rectangle on the first frame of selected video."
        }
    }
}
