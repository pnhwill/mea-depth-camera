//
//  LiveFaceDetectionProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//

import Vision
import UIKit

/// Detects faces from the selfie cam feed in real time.
class LiveFaceDetectionProcessor: VisionProcessor {
    
    let description: String = "LiveFaceDetectionProcessor"
    
    // MARK: Performing Vision Requests
    
    func performVisionRequests(on pixelBuffer: CVPixelBuffer, completion: (VNFaceObservation) -> Void) {
        // Create Vision request options dictionary containing the camera instrinsic matrix.
        var requestOptions = [VNImageOption: Any]()
        if let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }
        // Get current device orientation for request handler.
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
        // Create face rectangles and tell handler to perform the request.
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        do {
            try handler.perform([faceDetectionRequest])
            // Get face rectangles request containing facial orientation for alignment checking.
            if let faceObservations = faceDetectionRequest.results,
               let face = faceObservations.first {
                completion(face)
            }
        } catch {
            print("Vision error: \(error.localizedDescription)")
        }
    }
}

// MARK: Image Orientation
extension LiveFaceDetectionProcessor {
    // Helper Methods for Handling Device Orientation & EXIF.
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
        case .landscapeLeft:
            return .downMirrored
        case .landscapeRight:
            return .upMirrored
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}
