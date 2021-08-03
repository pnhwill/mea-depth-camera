//
//  VisionFaceTracker.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Detect and track faces from the selfie cam feed in real time.
*/

import AVFoundation
import Vision

protocol VisionFaceTrackerDelegate: AnyObject {
    func displayFrame(_ faceObservations: [VNFaceObservation], confidence: VNConfidence?)
    func checkAlignment(of faceObservation: VNFaceObservation)
    func stoppedTracking()
}

class VisionFaceTracker {
    
    let description: String = "VisionFaceTracker"
    
    var trackingLevel = VNRequestTrackingLevel.accurate
    
    weak var delegate: VisionFaceTrackerDelegate?
    
    // MARK: Performing Vision Requests
    
    func performVisionRequests(on pixelBuffer: CVPixelBuffer) {
        var requestOptions = [VNImageOption: Any]()
        if let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        do {
            try handler.perform([faceDetectionRequest])
            guard let faceObservations = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            var confidence: VNConfidence?
            if let face = faceObservations.first {
                // Get face landmarks confidence metric
                confidence = face.confidence
                // Get face rectangles request containing roll & yaw for alignment checking
                self.delegate?.checkAlignment(of: face)
            } else {
                delegate?.stoppedTracking()
            }
            self.delegate?.displayFrame(faceObservations, confidence: confidence)
        } catch {
            print("Vision error: \(error.localizedDescription)")
        }
    }
    
}
