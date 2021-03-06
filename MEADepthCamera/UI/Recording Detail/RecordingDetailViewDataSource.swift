//
//  RecordingDetailViewDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/23/21.
//

import UIKit

class RecordingDetailViewDataSource: NSObject {
    
    // MARK: RecordingRow
    enum RecordingRow: Int, CaseIterable {
        case name
        case task
        case duration
        case filesCount
        case isProcessed
        
        func displayText(for recording: Recording) -> String? {
            switch self {
            case .name:
                return recording.name
            case .task:
                return recording.task?.name
            case .duration:
                return recording.durationText
            case .filesCount:
                return String(recording.filesCount)
            case .isProcessed:
                return recording.isProcessed ? "Yes" : "No"
            }
        }
    }
    
    // Current recording
    var recording: Recording
    
    init(recording: Recording) {
        self.recording = recording
    }
    
}
