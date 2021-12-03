//
//  Enumerations.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation

enum LoggerCategory: String {
    case persistence = "Persistence"
    case parsing = "Parsing"
}

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

enum OldTrackingState {
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
