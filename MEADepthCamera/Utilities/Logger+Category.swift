//
//  LoggerCategory.swift
//  MEADepthCamera
//
//  Created by Will on 12/9/21.
//

import OSLog

extension Logger {
    private static let subsystem = Bundle.main.reverseDNS()
    
    enum Category: String {
        case persistence = "Persistence"
        case json = "JSON"
        case ui = "UI"
        case camera = "Camera"
        case vision = "Vision"
        case processing = "Processing"
        
        var logger: Logger {
            Logger(subsystem: Logger.subsystem, category: self.rawValue)
        }
    }
}
