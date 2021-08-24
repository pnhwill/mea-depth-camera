//
//  RecordingDetailDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/23/21.
//

import UIKit

class RecordingDetailDataSource: NSObject {
    
    // Current recording
    var recording: Recording
    
    init(recording: Recording) {
        self.recording = recording
    }
    
    
}
