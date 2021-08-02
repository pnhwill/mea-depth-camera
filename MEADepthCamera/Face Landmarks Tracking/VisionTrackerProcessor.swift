//
//  VisionTrackerProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/22/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the tracker processing logic using Vision.
*/

import AVFoundation
import UIKit
import Vision

protocol VisionTrackerProcessorDelegate: AnyObject {
    func displayFrame(_ faceObservations: VNFaceObservation, confidence: VNConfidence?, captureQuality: Float?)
    func checkAlignment(of faceObservation: VNFaceObservation)
    func recordLandmarks(of faceObservation: VNFaceObservation)
    func didFinishTracking()
}

class VisionTrackerProcessor {
    
    var description: String = "Vision Tracker Processor"
    // // Video frame buffer pool allocation
    var isPrepared = false
    //private(set) var inputFormatDescription: CMFormatDescription?
    private var inputPixelBufferPool: CVPixelBufferPool!
    
    var trackingLevel = VNRequestTrackingLevel.accurate
    
    weak var delegate: VisionTrackerProcessorDelegate?
    
    private var cancelRequested = false
    
    // Vision requests
    var detectionRequests: [VNDetectFaceRectanglesRequest]?
    var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // Vision face analysis
    var faceCaptureQuality: Float?
    var faceLandmarksConfidence: VNConfidence?
    
    // MARK: Allocate Pixel Buffer Pool
    func prepare(with formatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        reset()
        
        (inputPixelBufferPool, _, _) = allocateOutputBufferPool(with: formatDescription, outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        if inputPixelBufferPool == nil {
            print("Failed to allocation pixel buffer pool")
            return
        }
        //inputFormatDescription = formatDescription
        isPrepared = true
    }
    
    func reset() {
        inputPixelBufferPool = nil
        //inputFormatDescription = nil
        isPrepared = false
    }
    
    func copyPixelBuffer(inputBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        //autoreleasepool {
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, inputPixelBufferPool!, &newPixelBuffer)
        guard let copyBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool (\(self.description))")
            return nil
        }
        
        CVBufferPropagateAttachments(inputBuffer as CVBuffer, copyBuffer as CVBuffer)
        
        CVPixelBufferLockBaseAddress(inputBuffer, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(copyBuffer, CVPixelBufferLockFlags(rawValue: 0))

        let inputBaseAddress = CVPixelBufferGetBaseAddress(inputBuffer)
        let copyBaseAddress = CVPixelBufferGetBaseAddress(copyBuffer)

        defer {
            CVPixelBufferUnlockBaseAddress(inputBuffer, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferUnlockBaseAddress(copyBuffer, CVPixelBufferLockFlags(rawValue: 0))
            newPixelBuffer = nil
        }
        
        //print("copy data size: \(CVPixelBufferGetDataSize(copyBuffer))")
        //print("input data size: \(CVPixelBufferGetDataSize(inputBuffer))")
        memcpy(copyBaseAddress, inputBaseAddress, CVPixelBufferGetDataSize(copyBuffer))
        
        return copyBuffer
        //}
    }
    
    // MARK: Performing Vision Requests
    
    func performVisionRequests(on pixelBuffer: CVPixelBuffer, cameraIntrinsicData: AVCameraCalibrationData?) {
        // guard isPrepared else { return }
        
        guard cancelRequested == false else {
            delegate?.didFinishTracking()
            return
        }
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        if cameraIntrinsicData != nil {
            print("VisionTrackerProcessor: Camera intrinsic data not found.")
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // Hide the labels and drawings when no face is observed
            delegate?.didFinishTracking()
            // Nothing to track, so abort.
            return
        }
        
        // Perform face landmark tracking on detected faces.
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // Perform landmark detection on tracked faces.
        for trackingRequest in newTrackingRequests {
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                // NOTE: currently this means nil will never be fed to writeToCSV(), so instead of putting zeros it will just record nothing at all.
                // Missing frames can still be identified from the timestamp, though
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                      let results = landmarksRequest.results as? [VNFaceObservation] else {
                    return
                }
                
                // NOTE: this only calls for the first observation in the array if there multiple
                // Could make this so each face observation goes into a separate file (not necessary but safer)
                if let face = results.first {
                    // Get face landmarks confidence metric
                    let confidence = face.landmarks?.confidence
                    // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
                    DispatchQueue.main.async {
                        self.delegate?.displayFrame(face, confidence: confidence, captureQuality: self.faceCaptureQuality)
                    }
                    // Send face observation to delegate for data collection
                    self.delegate?.recordLandmarks(of: face)
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            
            // Continue to track detected facial landmarks.
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
            }
            
            // Get face rectangles request containing roll & yaw for alignment checking
            let faceRectanglesRequest = VNDetectFaceRectanglesRequest()
            do {
                try imageRequestHandler.perform([faceRectanglesRequest])
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectanglesRequest: %@", error)
            }
            if let face = faceRectanglesRequest.results?.first as? VNFaceObservation {
                delegate?.checkAlignment(of: face)
            } else {
                print("Could not check face alignment")
            }
            
            // Get face capture quality metric
            let faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest()
            faceCaptureQualityRequest.inputFaceObservations = [faceObservation]
            do {
                try imageRequestHandler.perform([faceCaptureQualityRequest])
            } catch let error as NSError {
                NSLog("Failed to perform FaceCaptureQualityRequest: %@", error)
            }
            
            guard let result = faceCaptureQualityRequest.results?.first as? VNFaceObservation,
                  let faceCaptureQuality = result.faceCaptureQuality else {
                print("Failed to produce face capture quality metric")
                return
            }
            self.faceCaptureQuality = faceCaptureQuality
        }
    }
    
    func prepareVisionRequest() {
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection. Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }
    
    func cancelTracking() {
        cancelRequested = true
    }
    
    // MARK: Helper Methods for Handling Device Orientation & EXIF
    
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
