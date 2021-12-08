//
//  FileWriterError.swift
//  MEADepthCamera
//
//  Created by Will on 12/7/21.
//

import AVFoundation

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
