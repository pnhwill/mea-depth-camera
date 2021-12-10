//
//  FaceLandmarksPipeline.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Vision

// MARK: FaceLandmarksPipelineDelegate
protocol FaceLandmarksPipelineDelegate: AnyObject {
    
    func displayFrameCounter(_ frame: Int)
    
    func didFinishTracking(success: Bool)
}

// MARK: FaceLandmarksPipeline
class FaceLandmarksPipeline: DataPipeline {
    
    weak var delegate: FaceLandmarksPipelineDelegate?
    
    // Current recording being processed
    private(set) var recording: Recording
    
    // Data Processors
    private var processorSettings: ProcessorSettings
    private var visionTrackerProcessor: LandmarksTrackerProcessor
    private var pointCloudProcessor: PointCloudProcessor
    private var lensDistortionCorrectionProcessor: LensDistortionCorrectionProcessor
    
    // File Writers
    private var faceLandmarks2DFileWriter: FaceLandmarksFileWriter
    private var faceLandmarks3DFileWriter: FaceLandmarksFileWriter
    private var infoFileWriter: InfoFileWriter
    
    // Video readers and assets
    private var videoReader: VideoReader?
    private var depthReader: VideoReader?
    private var videoAsset: AVAsset?
    private var depthAsset: AVAsset?
    
    private var cancelRequested = false
    
    init?(recording: Recording) {
        guard let processorSettings = recording.processorSettings,
              let infoFileWriter = InfoFileWriter(recording: recording),
              let faceLandmarks2DFileWriter = FaceLandmarksFileWriter(recording: recording, outputType: .landmarks2D),
              let faceLandmarks3DFileWriter = FaceLandmarksFileWriter(recording: recording, outputType: .landmarks3D)
        else {
            print("Failed to initialize FaceLandmarksPipeline: recording is missing data.")
            return nil
        }
        self.processorSettings = processorSettings
        self.recording = recording
        self.visionTrackerProcessor = LandmarksTrackerProcessor(processorSettings: processorSettings)
        self.pointCloudProcessor = PointCloudProcessor(settings: processorSettings)
        self.infoFileWriter = infoFileWriter
        self.faceLandmarks2DFileWriter = faceLandmarks2DFileWriter
        self.faceLandmarks3DFileWriter = faceLandmarks3DFileWriter
        self.lensDistortionCorrectionProcessor = LensDistortionCorrectionProcessor(settings: processorSettings)
    }
    
    // MARK: - Pipeline Setup
    
    func startTracking() throws {
        // Load RGB and depth map video files from saved URLs.
        guard let (videoAsset, depthAsset) = recording.loadAssets(),
              let saveFolder = recording.folderURL
        else {
            throw VisionTrackerProcessorError.fileNotFound
        }
        self.videoAsset = videoAsset
        self.depthAsset = depthAsset
        
        self.recording.addFiles(newFiles: [.landmarks2D: faceLandmarks2DFileWriter.fileURL,
                                           .landmarks3D: faceLandmarks3DFileWriter.fileURL,
                                           .info: infoFileWriter.fileURL])
        
        // Write the recording information to file now that totalFrames has been computed.
        // (somewhat abusing the fact that the recording's folder is named using the start time of the recording).
        infoFileWriter.writeInfoRow(startTime: saveFolder.lastPathComponent, totalFrames: Int(recording.totalFrames))
        
        // Try to perform the video tracking.
        try self.performTracking()
    }
    
    func cancelTracking() {
        cancelRequested = true
    }
    
    // MARK: Read Video and Perform Tracking
    private func performTracking() throws {
        guard let videoAsset = videoAsset, let depthAsset = depthAsset,
              let videoReader = VideoReader(videoAsset: videoAsset, videoDataType: .video),
              let depthReader = VideoReader(videoAsset: depthAsset, videoDataType: .depth) else {
            throw VisionTrackerProcessorError.readerInitializationFailed
        }
        self.videoReader = videoReader
        self.depthReader = depthReader
        
        guard videoReader.nextFrame() != nil else {
            throw VisionTrackerProcessorError.firstFrameReadFailed
        }
        
        cancelRequested = false
        
        visionTrackerProcessor.prepareVisionRequest()
        
        var frames = 0
        
        var nextDepthFrame: CMSampleBuffer? = depthReader.nextFrame()
        var nextDepthImage: CVPixelBuffer?
        if let depthFrame = nextDepthFrame {
            nextDepthImage = CMSampleBufferGetImageBuffer(depthFrame)
        }
        
        func trackAndRecord(video: CVPixelBuffer, depth: CVPixelBuffer?, _ frame: Int, _ timeStamp: Float64) throws {
            try visionTrackerProcessor.performVisionRequests(on: video, orientation: videoReader.orientation, completion: { faceObservation in
                self.recordLandmarks(of: faceObservation, with: depth, frame: frame, timeStamp: timeStamp)
                // Display the frame counter in the UI on the main thread.
                DispatchQueue.main.async {
                    self.delegate?.displayFrameCounter(frame)
                }
            })
        }
        
        while true {
            guard cancelRequested == false, let videoFrame = videoReader.nextFrame() else {
                break
            }
            
            frames += 1
            
            let videoTime = CMTimeGetSeconds(videoFrame.presentationTimeStamp)
            
            guard let videoImage = CMSampleBufferGetImageBuffer(videoFrame) else {
                print("No image found in video sample")
                break
            }
            
            // We may run out of depth frames before video frames, but we don't want to break the loop
            if let depthFrame = nextDepthFrame, let depthImage = nextDepthImage {
                
                let depthTime = CMTimeGetSeconds(depthFrame.presentationTimeStamp)
                // If there is a dropped frame, then the videos will become misaligned and it will never record the depth data, so we must compare the timestamps
                // This doesn't exactly work if many frames are dropped early, so we need another way to check (frame index?)
                switch (videoTime, depthTime) {
                case let (videoTime, depthTime) where videoTime < depthTime:
                    // Video frame is before depth frame, so don't send the depth data to record
                    try trackAndRecord(video: videoImage, depth: nil, frames, videoTime)
                    // Start at beginning of next loop iteration without getting a new depth frame from the reader
                    print("<")
                    continue
                case let (videoTime, depthTime) where videoTime == depthTime:
                    // Frames match, so send the depth data to be recorded
                    try trackAndRecord(video: videoImage, depth: depthImage, frames, videoTime)
                    print("=")
                //case let (videoTime, depthTime) where videoTime > depthTime:
                default:
                    // Video frame is after depth frame, so don't send the depth data
                    print(">")
                    try trackAndRecord(video: videoImage, depth: nil, frames, videoTime)
                }
            } else {
                // No more depth data
                print("No more depth data frames found")
                try trackAndRecord(video: videoImage, depth: nil, frames, videoTime)
            }
            
            // Get the next depth frame from the reader
            nextDepthFrame = depthReader.nextFrame()
            if let depthFrame = nextDepthFrame {
                nextDepthImage = CMSampleBufferGetImageBuffer(depthFrame)
            }
            
        }
        
        delegate?.didFinishTracking(success: !cancelRequested)
    }
    
    // MARK: - Landmarks Depth Processing
    
    /// Combines a face observation and depth data to produce a bounding box and face landmarks in 3D space.
    ///
    /// If no depth is provided, it returns the 2D landmarks in image coordinates.
    /// If no landmarks are provided, it returns just the bounding box.
    /// If no face observation is provided, it returns all zeros.
    private func processFace(_ faceObservation: VNFaceObservation?, with depthDataMap: CVPixelBuffer?) -> (CGRect, [vector_float3], [vector_float3]?) {
        
        // In case the face is lost in the middle of collecting data, this prevents empty or nil-valued cells in the file so it can still be parsed later.
        var boundingBox = CGRect.zero
        var landmarks2D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        var landmarks3D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        
        if let faceObservation = faceObservation {
            // Get face bounding box in RGB image coordinates.
            boundingBox = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(processorSettings.videoResolution.width), Int(processorSettings.videoResolution.height))
            
            if let landmarks = faceObservation.landmarks?.allPoints {
                
                if let depthDataMap = depthDataMap, let correctedDepthMap = rectifyDepthMapGPU(depthDataMap: depthDataMap) {
                    
                    let landmarkPoints = landmarks.pointsInImage(imageSize: processorSettings.depthResolution)
                    
                    let correctedLandmarks = landmarkPoints.map { rectifyLandmark(landmark: $0) }
                    
                    let landmarkVectors = landmarkPoints.map { simd_float2(Float($0.x), Float($0.y)) }
                    let correctedLandmarkVectors = correctedLandmarks.map { simd_float2(Float($0!.x), Float($0!.y)) }
                    
                    if !pointCloudProcessor.isPrepared {
                        var depthFormatDescription: CMFormatDescription?
                        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                     imageBuffer: correctedDepthMap,
                                                                     formatDescriptionOut: &depthFormatDescription)
                        if let unwrappedDepthFormatDescription = depthFormatDescription {
                            pointCloudProcessor.prepare(with: unwrappedDepthFormatDescription)
                        }
                    }
                    guard let landmarkPointCloud = pointCloudProcessor.render(landmarks: correctedLandmarkVectors, depthFrame: correctedDepthMap) else {
                        // If any of the landmarks fails to be processed, it discards the rest and returns just as if no depth was given.
                        print("Metal point cloud processor failed to output landmark position. Returning landmarks in RGB image coordinates.")
                        let landmarkPoints = landmarks.pointsInImage(imageSize: processorSettings.videoResolution)
                        landmarks2D = landmarkPoints.map { simd_make_float3(Float($0.x), Float($0.y), 0.0) }
                        return (boundingBox, landmarks2D, nil)
                    }
                    
                    for (index, _) in landmarks.normalizedPoints.enumerated() {
                        landmarks2D[index] = simd_make_float3(landmarkVectors[index], landmarkPointCloud[index].z)
                        landmarks3D[index] = landmarkPointCloud[index]
                    }
                } else {
                    //print("No depth data found. Returning 2D landmarks in RGB image coordinates.")
                    let landmarkPoints = landmarks.pointsInImage(imageSize: processorSettings.videoResolution)
                    landmarks2D = landmarkPoints.map { simd_make_float3(Float($0.x), Float($0.y), 0.0) }
                    return (boundingBox, landmarks2D, nil)
                }
            } else {
                print("Invalid face detection request: no face landmarks. Returning bounding box only.")
                return (boundingBox, landmarks2D, nil)
            }
        } else {
            print("No face observation found. Inserting zeros for all values.")
            return (boundingBox, landmarks2D, nil)
        }
        return (boundingBox, landmarks2D, landmarks3D)
    }
    
    /// Write face observation results to file if collecting data.
    private func recordLandmarks(of faceObservation: VNFaceObservation, with depthDataMap: CVPixelBuffer?, frame: Int, timeStamp: Float64) {
        
        // Perform data collection in background queue so that it does not hold up the UI.
        let (boundingBox, landmarks2D, landmarks3D) = processFace(faceObservation, with: depthDataMap)
        faceLandmarks2DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks2D)
        if let landmarks3D = landmarks3D {
            faceLandmarks3DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks3D)
        }
    }
}

// MARK: Lens Distortion Correction
extension FaceLandmarksPipeline {
    
    /// Rectify the depth data map from lens-distorted to rectilinear coordinate space.
    private func rectifyDepthMapGPU(depthDataMap: CVPixelBuffer) -> CVPixelBuffer? {
        if !lensDistortionCorrectionProcessor.isPrepared {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: depthDataMap,
                                                         formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                lensDistortionCorrectionProcessor.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 3)
            }
        }
        let correctedDepthMap = lensDistortionCorrectionProcessor.render(pixelBuffer: depthDataMap)
        if correctedDepthMap == nil {
            print("Metal lens distortion correction processor failed to render depth map. Returning landmarks in RGB image coordinates.")
        }
        return correctedDepthMap
    }
    
    private func rectifyLandmark(landmark: CGPoint) -> CGPoint? {
        // Get camera instrinsics
        guard let cameraCalibrationData = (processorSettings.decodedCameraCalibrationData ?? processorSettings.cameraCalibrationData) as? CameraCalibrationDataProtocol,
              let lookupTable = cameraCalibrationData.inverseLensDistortionLookupTable else {
            print("FaceLandmarksPipeline.rectifyLandmark: Could not find camera calibration data")
            return nil
        }
        let referenceDimensions: CGSize = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        let opticalCenter: CGPoint = cameraCalibrationData.lensDistortionCenter
        
        let ratio: Float = Float(referenceDimensions.width) / Float(processorSettings.depthResolution.width)
        let scaledOpticalCenter = CGPoint(x: opticalCenter.x / CGFloat(ratio), y: opticalCenter.y / CGFloat(ratio))
        
        let outputPoint = lensDistortionPointForPoint(landmark, lookupTable, scaledOpticalCenter, processorSettings.depthResolution)
        
        return outputPoint
    }
}
