//
//  Enumerations.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import Foundation

enum RecordingState {
    case idle, start, recording, finish
}

enum WriteState {
    case inactive, active
}

struct ProcessorSettings {
    var videoResolution: CGSize = CGSize()
    var depthResolution: CGSize = CGSize()
    var numLandmarks: Int = 76
}
