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
        self.videoResolution = CGSize(width: Int(videoDimensions.width), height: Int(videoDimensions.height))
        self.depthResolution = CGSize(width: Int(depthDimensions.width), height: Int(depthDimensions.height))
    }
    
    func getTransform() -> CGAffineTransform {
        // The TrueDepth camera is in the front position
        let angleOffset = CGFloat(videoOrientation.angleOffsetFromPortraitOrientation(at: .front))
        let transform = CGAffineTransform(rotationAngle: angleOffset)
        return transform
    }
    
    func getPortraitResolutions() -> (CGSize, CGSize) {
        let portraitVideoResolution = CGRect(x: 0, y: 0, width: CGFloat(videoResolution.width), height: CGFloat(videoResolution.height)).applying(getTransform()).standardized.size.rounded()
        let portraitDepthResolution = CGRect(x: 0, y: 0, width: CGFloat(depthResolution.width), height: CGFloat(depthResolution.height)).applying(getTransform()).standardized.size.rounded()
        return (portraitVideoResolution, portraitDepthResolution)
    }
}

struct SavedFile: Codable {
    let outputType: OutputType
    let lastPathComponent: String
}

struct SavedRecording: Codable {
    let name: String
    let folderURL: URL
    let duration: Double?
    let task: SavedTask?
    var savedFiles: [SavedFile]
}

struct SavedUseCase: Codable {
    var id: UUID
    var title: String
    var date: Date
    var subjectID: String
    var recordings: [SavedRecording]
    var notes: String? = nil
}

struct SavedTask: Codable {
    let name: String
    let fileNameLabel: String?
    let instructions: String?
    let repTime: Int?
    let repetitions: Int?
    let recordVideo: Bool?
    let recordAudio: Bool?
}
