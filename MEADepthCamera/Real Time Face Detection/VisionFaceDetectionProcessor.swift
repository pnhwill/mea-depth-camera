//
//  VisionFaceDetectionProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Detect faces from the selfie cam feed in real time.
*/

import AVFoundation
import Vision

protocol VisionFaceDetectionProcessorDelegate: AnyObject {
    func displayFrame(_ faceObservations: [VNFaceObservation])
    func checkAlignment(of faceObservation: VNFaceObservation)
}

class VisionFaceDetectionProcessor {
    
    let description: String = "VisionFaceDetectionProcessor"
    
    weak var delegate: VisionFaceDetectionProcessorDelegate?
    
    // MARK: Performing Vision Requests
    
    func performVisionRequests(on pixelBuffer: CVPixelBuffer) {
        // Create Vision request options dictionary containing the camera instrinsic matrix
        var requestOptions = [VNImageOption: Any]()
        if let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }
        // Get current device orientation for request handler
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
        // Create face rectangles and tell handler to perform the request
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        do {
            try handler.perform([faceDetectionRequest])
            guard let faceObservations = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            if let face = faceObservations.first {
                // Get face rectangles request containing roll & yaw for alignment checking
                self.delegate?.checkAlignment(of: face)
            }
            self.delegate?.displayFrame(faceObservations)
        } catch {
            print("Vision error: \(error.localizedDescription)")
        }
    }
    
}
