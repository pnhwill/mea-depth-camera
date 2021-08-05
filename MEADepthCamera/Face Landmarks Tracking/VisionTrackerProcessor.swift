//
//  VisionTrackerProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 8/2/21.
//
/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Contains the face tracker post-processing logic using Vision.
 */

import AVFoundation
import Vision

protocol VisionTrackerProcessorDelegate: AnyObject {
    func recordLandmarks(of faceObservation: VNFaceObservation, with depthMap: CVPixelBuffer?, frame: Int)
    func didFinishTracking()
}

class VisionTrackerProcessor {
    
    let description: String = "VisionTrackerProcessor"
    
    weak var delegate: VisionTrackerProcessorDelegate?
    
    private var videoAsset: AVAsset
    private var videoReader: VideoReader?
    private var depthAsset: AVAsset
    private var depthReader: VideoReader?
    
    // Vision requests
    private var trackingLevel = VNRequestTrackingLevel.accurate
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    private let processorSettings: ProcessorSettings
    
    private var cancelRequested = false
    
    init(videoAsset: AVAsset, depthAsset: AVAsset, processorSettings: ProcessorSettings) {
        self.videoAsset = videoAsset
        self.depthAsset = depthAsset
        self.processorSettings = processorSettings
    }
    
    func performTracking() throws {
        guard let videoReader = VideoReader(videoAsset: videoAsset),
              let depthReader = VideoReader(videoAsset: depthAsset) else {
            throw VisionTrackerProcessorError.readerInitializationFailed
        }
        self.videoReader = videoReader
        self.depthReader = depthReader
        
        guard videoReader.nextFrame() != nil else {
            throw VisionTrackerProcessorError.firstFrameReadFailed
        }
        
        cancelRequested = false
        
        self.prepareVisionRequest()
        
        var frames = 1
        
        var nextDepthFrame: CMSampleBuffer? = depthReader.nextFrame()
        
        func trackAndRecord(video: CVPixelBuffer, depth: CVPixelBuffer?) throws {
            try performVisionRequests(on: video, completion: { faceObservation in
                self.delegate?.recordLandmarks(of: faceObservation, with: depth, frame: frames)
            })
        }
        
        while true {
            guard cancelRequested == false, let videoFrame = videoReader.nextFrame() else {
                break
            }
            
            frames += 1
            
            guard let videoImage = CMSampleBufferGetImageBuffer(videoFrame) else {
                print("\(description): No image found in video sample")
                break
            }
            
            // We may run out of depth frames before video frames, but we don't want to break the loop
            if let depthFrame = nextDepthFrame, let depthImage = CMSampleBufferGetImageBuffer(depthFrame) {
                let videoTimeStamp = videoFrame.presentationTimeStamp
                let depthTimeStamp = depthFrame.presentationTimeStamp
                // If there is a dropped frame, then the videos will become misaligned and it will never record the depth data, so we must compare the timestamps
                // This doesn't exactly work if many frames are dropped early, so we need another way to check (frame index?)
                switch (CMTimeGetSeconds(videoTimeStamp), CMTimeGetSeconds(depthTimeStamp)) {
                case let (videoTime, depthTime) where videoTime < depthTime:
                    // Video frame is before depth frame, so don't send the depth data to record
                    try trackAndRecord(video: videoImage, depth: nil)
                    // Start at beginning of next loop iteration without getting a new depth frame from the reader
                    print("<")
                    continue
                case let (videoTime, depthTime) where videoTime == depthTime:
                    // Frames match, so send the depth data to be recorded
                    try trackAndRecord(video: videoImage, depth: depthImage)
                    print("=")
                //case let (videoTime, depthTime) where videoTime > depthTime:
                default:
                    // Video frame is after depth frame, so don't send the depth data
                    print(">")
                    try trackAndRecord(video: videoImage, depth: nil)
                }
            } else {
                // No more depth data
                print("\(description): No depth data found")
                try trackAndRecord(video: videoImage, depth: nil)
            }
            
            // Get the next depth frame from the reader
            nextDepthFrame = depthReader.nextFrame()
        }
        
        delegate?.didFinishTracking()
        
    }
    
    private func prepareVisionRequest() {
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("\(self.description): FaceDetection error: \(String(describing: error)).")
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
    
    private func performVisionRequests(on pixelBuffer: CVPixelBuffer, completion: @escaping (VNFaceObservation) -> Void) throws {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        

        
        if let cameraIntrinsics = processorSettings.cameraCalibrationData?.intrinsicMatrix {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsics as AnyObject
        } else {
            print("\(description): Camera intrinsic data not found.")
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
                print("\(description): Failed to perform FaceRectangleRequest: \(error.localizedDescription)")
                throw VisionTrackerProcessorError.faceRectangleDetectionFailed
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
            print("\(description): Failed to perform SequenceRequest: \(error.localizedDescription)")
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
                    print("\(self.description): FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                      let results = landmarksRequest.results as? [VNFaceObservation] else {
                    return
                }
                
                if let face = results.first {
                    // Send face observation to caller for data collection
                    completion(face)
                } else {
                    print("\(self.description): No face observation returned from landmarks request.")
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
                print("\(description): Failed to perform FaceRectanglesRequest: \(error.localizedDescription)")
                throw VisionTrackerProcessorError.faceTrackingFailed
            }
            
        }
    }
    
    func cancelTracking() {
        cancelRequested = true
    }
    
}
