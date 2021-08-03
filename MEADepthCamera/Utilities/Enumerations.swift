//
//  Enumerations.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation

enum RecordingState {
    case idle, start, recording, finish
}

enum WriteState {
    case inactive, active
}

enum FileWriteResult {
    case success
    case failed(Error?)
}

enum TrackingState {
    case tracking
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
