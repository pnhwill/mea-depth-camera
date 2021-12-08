//
//  ProcessorSettings.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import AVFoundation

/// Encapsulation of capture information used by the video processing pipelines, which is stored in each recording.
public class ProcessorSettings: NSObject {
    
    // The number of landmarks depends on the Vision request revision.
    var numLandmarks: Int = 76
    // These sizes represent the final output resolutions in portrait orientation.
    var videoResolution: CGSize
    var depthResolution: CGSize
    // The video/depth frames are delivered in landscapeLeft orientation, so we need to know how to rotate their dimensions.
    var videoOrientation: AVCaptureVideoOrientation
    // We have to wait until we receive the first depth frame to set the camera calibration data.
    var cameraCalibrationData: AVCameraCalibrationData?
    var decodedCameraCalibrationData: CodingCameraCalibrationData?
    
    init(videoDimensions: CMVideoDimensions, depthDimensions: CMVideoDimensions, videoOrientation: AVCaptureVideoOrientation) {
        self.videoOrientation = videoOrientation
        self.videoResolution = CGSize(width: Int(videoDimensions.width), height: Int(videoDimensions.height))
        self.depthResolution = CGSize(width: Int(depthDimensions.width), height: Int(depthDimensions.height))
        super.init()
    }
    
    // Required initializer for NSSecureCoding.
    public required init?(coder: NSCoder) {
        let numLandmarks = coder.decodeInteger(forKey: CodingKeys.numLandmarks.rawValue)
        let videoResolution = coder.decodeCGSize(forKey: CodingKeys.videoResolution.rawValue)
        let depthResolution = coder.decodeCGSize(forKey: CodingKeys.depthResolution.rawValue)
        guard let videoOrientation = AVCaptureVideoOrientation(rawValue: coder.decodeInteger(forKey: CodingKeys.videoOrientation.rawValue)) else { return nil }
        guard let cameraCalibrationData = coder.decodeObject(of: CodingCameraCalibrationData.self, forKey: CodingKeys.cameraCalibrationData.rawValue) else {
            print("ProcessorSettings failed to decode the camera calibration data")
            return nil
        }
        
        self.numLandmarks = numLandmarks
        self.videoResolution = videoResolution
        self.depthResolution = depthResolution
        self.videoOrientation = videoOrientation
        self.decodedCameraCalibrationData = cameraCalibrationData
    }
}

// MARK: Convenience Getter Methods
extension ProcessorSettings {
    func getTransform() -> CGAffineTransform {
        // The TrueDepth camera is in the front position.
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

// MARK: NSSecureCoding
extension ProcessorSettings: NSSecureCoding {
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    private enum CodingKeys: String, CodingKey {
        case numLandmarks
        case videoResolution
        case depthResolution
        case videoOrientation
        case cameraCalibrationData
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(numLandmarks, forKey: CodingKeys.numLandmarks.rawValue)
        coder.encode(videoResolution, forKey: CodingKeys.videoResolution.rawValue)
        coder.encode(depthResolution, forKey: CodingKeys.depthResolution.rawValue)
        coder.encode(videoOrientation.rawValue, forKey: CodingKeys.videoOrientation.rawValue)
        if let cameraCalibrationData = cameraCalibrationData {
            let codingCameraCalibrationData = CodingCameraCalibrationData(from: cameraCalibrationData)
            coder.encode(codingCameraCalibrationData, forKey: CodingKeys.cameraCalibrationData.rawValue)
        } else {
            coder.encode(decodedCameraCalibrationData, forKey: CodingKeys.cameraCalibrationData.rawValue)
        }
    }
}
