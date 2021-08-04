//
//  CommonTypes.swift
//  MEADepthCamera
//
//  Created by Will on 7/30/21.
//

import AVFoundation

struct ProcessorSettings {
    var numLandmarks: Int = 76
    var videoResolution: CGSize = CGSize()
    var depthResolution: CGSize = CGSize()
    var cameraCalibrationData: AVCameraCalibrationData?
    
    func getProperties() -> (Int, CGSize, CGSize) {
        return (numLandmarks, videoResolution, depthResolution)
    }
}

struct SavedFile {
    let outputType: OutputType
    let lastPathComponent: String
}

struct SavedRecording {
    let name: String
    let folderURL: URL
    let savedFiles: [SavedFile]
}
