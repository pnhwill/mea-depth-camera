//
//  OutputType.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import Foundation

/// Enumeration of the different output files saved to the device.
enum OutputType: String {
    case video
    case audio
    case depth
    case landmarks2D
    case landmarks3D
    case info
    case frameIndex
    
    var fileExtension: String {
        switch self {
        case .video, .depth:
            return "mov"
        case .audio:
            return "wav"
        case .landmarks2D, .landmarks3D, .info, .frameIndex:
            return "csv"
        }
    }
}
