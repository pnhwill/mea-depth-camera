//
//  LandmarksTrackerProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 8/2/21.
//

import AVFoundation
import Vision
import OSLog

/// Contains the face tracker post-processing logic using Vision.
class LandmarksTrackerProcessor: VisionProcessor {
    
    let description: String = "LandmarksTrackerProcessor"
    
    private let processorSettings: ProcessorSettings
    
    // Vision requests
//    private var trackingLevel = VNRequestTrackingLevel.accurate
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    private let logger = Logger.Category.vision.logger
    
    init(processorSettings: ProcessorSettings) {
        self.processorSettings = processorSettings
    }
    
    // MARK: Prepare Vision Request
    
    func prepareVisionRequest() {
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                self.logger.error("\(self.description) - FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results else {
                return
            }
            DispatchQueue.main.async {
                // Add the observations to the tracking list.
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
    
    // MARK: Perform Vision Requests
    
    func performVisionRequests(on pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, completion: @escaping (VNFaceObservation) -> Void) throws {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        if let cameraCalibrationData = (processorSettings.decodedCameraCalibrationData ?? processorSettings.cameraCalibrationData) as? CameraCalibrationDataProtocol {
            let cameraIntrinsics = cameraCalibrationData.intrinsicMatrix
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsics as AnyObject
        } else {
            logger.info("\(self.description) - Camera intrinsic data not found.")
        }
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection.
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: orientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                logger.error("\(self.description) - Failed to perform FaceRectangleRequest: \(error) - \(error.localizedDescription)")
                throw VisionTrackerProcessorError.faceRectangleDetectionFailed
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: orientation)
        } catch let error as NSError {
            logger.error("\(self.description) - Failed to perform SequenceRequest: \(error) - \(error.localizedDescription)")
            throw VisionTrackerProcessorError.faceTrackingFailed
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
                    self.logger.error("\(self.description) - FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                      let results = landmarksRequest.results else {
                    return
                }
                
                if let face = results.first {
                    // Send face observation to caller for data collection.
                    completion(face)
                } else {
                    self.logger.notice("\(self.description) - No face observation returned from landmarks request.")
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
                                                            orientation: orientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                logger.error("\(self.description) - Failed to perform FaceRectanglesRequest: \(error) - \(error.localizedDescription)")
                throw VisionTrackerProcessorError.faceTrackingFailed
            }
        }
    }
}
