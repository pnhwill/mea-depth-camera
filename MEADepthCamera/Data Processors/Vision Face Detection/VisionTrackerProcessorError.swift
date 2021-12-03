//
//  VisionTrackerProcessorError.swift
//  MEADepthCamera
//
//  Created by Will on 12/3/21.
//

import Foundation

enum VisionTrackerProcessorError: Error {
    case fileNotFound
    case readerInitializationFailed
    case firstFrameReadFailed
    case faceTrackingFailed
    case faceRectangleDetectionFailed
}

extension VisionTrackerProcessorError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File does not exist at specified URL."
        case .readerInitializationFailed:
            return "Cannot create a Video Reader for selected video."
        case .firstFrameReadFailed:
            return "Cannot read the first frame from selected video."
        case .faceTrackingFailed:
            return "Tracking of detected face failed."
        case .faceRectangleDetectionFailed:
            return "Face Rectangle Detector failed to detect face rectangle on the first frame of selected video."
        }
    }
}
