//
//  FaceLandmarksProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Vision

class FaceLandmarksProcessor {
    
    // Weak reference to camera view controller
    private weak var cameraViewController: CameraViewController?
    
    private var processorSettings: ProcessorSettings
    
    // Point cloud Metal renderer with compute kernel
    private var pointCloudProcessor: PointCloudProcessor
    
    private(set) var faceLandmarksFileWriter: FaceLandmarksFileWriter
    
    init(cameraViewController: CameraViewController, settings: ProcessorSettings) {
        self.cameraViewController = cameraViewController
        self.processorSettings = settings
        self.pointCloudProcessor = PointCloudProcessor(settings: processorSettings)
        self.faceLandmarksFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
    }
    
    //var lookupTable: [Float]?
    
    // MARK: - Methods to get depth data for landmarks
    
    func processFace(_ faceObservation: VNFaceObservation?, with depthDataMap: CVPixelBuffer?) -> (CGRect, [vector_float3]) {
        // This method combines a face observation and depth data to produce a bounding box and face landmarks in 3D space.
        // If no depth is provided, it returns the 2D landmarks in image coordinates.
        // If no landmarks are provided, it returns just the bounding box.
        // If no face observation is provided, it returns all zeros.
        
        // In case the face is lost in the middle of collecting data, this prevents empty or nil-valued cells in the file so it can still be parsed later
        var boundingBox = CGRect.zero
        var landmarks3D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        
        if let faceObservation = faceObservation {
            // Get face bounding box in RGB image coordinates
            boundingBox = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(processorSettings.videoResolution.width), Int(processorSettings.videoResolution.height))
            
            if let landmarks = faceObservation.landmarks?.allPoints {

                if let depthDataMap = depthDataMap {
                    
                    let landmarkPoints = landmarks.pointsInImage(imageSize: processorSettings.depthResolution)
                    let landmarkVectors = landmarkPoints.map { simd_float2(Float($0.x), Float($0.y)) }
                    
                    if !pointCloudProcessor.isPrepared {
                        var depthFormatDescription: CMFormatDescription?
                        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                     imageBuffer: depthDataMap,
                                                                     formatDescriptionOut: &depthFormatDescription)
                        if let unwrappedDepthFormatDescription = depthFormatDescription {
                            pointCloudProcessor.prepare(with: unwrappedDepthFormatDescription)
                        }
                    }
                    pointCloudProcessor.render(landmarks: landmarkVectors, depthFrame: depthDataMap)
                    
                    for (index, _) in landmarks.normalizedPoints.enumerated() {
                        guard let landmarkPoint = pointCloudProcessor.getOutput(index: index) else {
                            // If any of the landmarks fails to be processed, it discards the rest and returns just as if no depth was given
                            print("Metal point cloud processor failed to output landmark position. Returning landmarks in RGB image coordinates.")
                            let landmarkPoints = landmarks.pointsInImage(imageSize: processorSettings.videoResolution)
                            landmarks3D = landmarkPoints.map { simd_make_float3(Float($0.x), Float($0.y), 0.0) }
                            return (boundingBox, landmarks3D)
                        }
                        landmarks3D[index] = landmarkPoint
                    }
                } else {
                    print("No depth data found. Returning 2D landmarks in RGB image coordinates.")
                    let landmarkPoints = landmarks.pointsInImage(imageSize: processorSettings.videoResolution)
                    landmarks3D = landmarkPoints.map { simd_make_float3(Float($0.x), Float($0.y), 0.0) }
                }
            } else {
                print("Invalid face detection request: no face landmarks. Returning bounding box only.")
            }
        } else {
            print("No face observation found. Inserting zeros for all values.")
        }
        return (boundingBox, landmarks3D)
    }
}

// MARK: - VisionTrackerProcessorDelegate Methods

extension FaceLandmarksProcessor: VisionTrackerProcessorDelegate {
    
    func recordLandmarks(of faceObservation: VNFaceObservation, with depthDataMap: CVPixelBuffer?, frame: Int) {
        // Write face observation results to file if collecting data.
        // Perform data collection in background queue so that it does not hold up the UI.
        
        let (boundingBox, landmarks) = processFace(faceObservation, with: depthDataMap)
        faceLandmarksFileWriter.writeToCSV(boundingBox: boundingBox, landmarks: landmarks)
        
        // Display the frame counter on the UI
        cameraViewController?.displayFrameCounter(frame)
    }
    
    func didFinishTracking() {
        faceLandmarksFileWriter.reset()
        DispatchQueue.main.async {
            self.cameraViewController?.trackingState = .stopped
            self.cameraViewController?.processingMode = .record
        }
    }
}
