//
//  VisionTrackerProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 8/2/21.
//
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the tracker post-processing logic using Vision.
*/

import AVFoundation
import Vision

enum VisionTrackerProcessorError: Error {
    case readerInitializationFailed
    case firstFrameReadFailed
    case objectTrackingFailed
    case rectangleDetectionFailed
}

protocol VisionTrackerProcessorDelegate: AnyObject {
    func recordLandmarks(of faceObservation: VNFaceObservation)
    func didFinishTracking()
    
}

class VisionTrackerProcessor {
    
    let description: String = "VisionTrackerProcessor"
    
    weak var delegate: VisionTrackerProcessorDelegate?
    
    var videoAsset: AVAsset!
    
    var videoReader: VideoReader?
    
    // Vision requests
    var trackingLevel = VNRequestTrackingLevel.accurate
    var detectionRequests: [VNDetectFaceRectanglesRequest]?
    var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    var cameraIntrinsicData: AVCameraCalibrationData?
    
    private var cancelRequested = false
    
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
    
    func performVisionRequests(on pixelBuffer: CVPixelBuffer) {
        guard cancelRequested == false else {
            return
        }
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        if cameraIntrinsicData != nil {
            print("\(description): Camera intrinsic data not found.")
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        let exifOrientation = CGImagePropertyOrientation.leftMirrored
        
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
                NSLog("Failed to perform FaceRectanglesRequest: %@", error)
            }
            
        }
    }
    
    func cancelTracking() {
        cancelRequested = true
    }
    
}
