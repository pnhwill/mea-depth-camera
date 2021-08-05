//
//  CommonTypes.swift
//  MEADepthCamera
//
//  Created by Will on 7/30/21.
//

import AVFoundation

struct ProcessorSettings {
    // The number of landmarks depends on the Vision request revision
    var numLandmarks: Int = 76
    // These sizes represent the final output resolutions in portrait orientation
    var videoResolution: CGSize
    var depthResolution: CGSize
    // The video/depth frames are delivered in landscapeLeft orientation, so we need to know how to rotate their dimensions
    var videoOrientation: AVCaptureVideoOrientation
    // We have to wait until we receive the first depth frame to set the camera calibration data
    var cameraCalibrationData: AVCameraCalibrationData?
    
    init(videoDimensions: CMVideoDimensions, depthDimensions: CMVideoDimensions, videoOrientation: AVCaptureVideoOrientation) {
        self.videoOrientation = videoOrientation
        // The TrueDepth camera is in the front position
        let angleOffset = CGFloat(videoOrientation.angleOffsetFromPortraitOrientation(at: .front))
        let transform = CGAffineTransform(rotationAngle: angleOffset)
        self.videoResolution = CGRect(x: 0, y: 0, width: CGFloat(videoDimensions.width), height: CGFloat(videoDimensions.height)).applying(transform).standardized.size.rounded()
        self.depthResolution = CGRect(x: 0, y: 0, width: CGFloat(depthDimensions.width), height: CGFloat(depthDimensions.height)).applying(transform).standardized.size.rounded()
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
