//
//  Enumerations.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import Foundation

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
