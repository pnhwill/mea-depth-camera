//
//  FaceLandmarksPipeline.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Vision
import OSLog

// MARK: - FaceLandmarksPipelineDelegate
protocol FaceLandmarksPipelineDelegate: AnyObject {
    
    func displayFrameCounter(_ frame: Int)
    
    func didFinishTracking(success: Bool)
}

// MARK: - FaceLandmarksPipeline

/// The `FaceLandmarksPipeline` class implements the post-processing pipeline for face landmarks tracking on previously recorded videos.
///
class FaceLandmarksPipeline {
    
    weak var delegate: FaceLandmarksPipelineDelegate?
    
    // Current recording being processed
    let recording: Recording
    
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
    
    private let logger = Logger.Category.processing.logger
    
    private var recordingName: String {
        recording.name!
    }
    
    init?(recording: Recording) {
        guard let processorSettings = recording.processorSettings,
              let infoFileWriter = InfoFileWriter(recording: recording),
              let faceLandmarks2DFileWriter = FaceLandmarksFileWriter(recording: recording, outputType: .landmarks2D),
              let faceLandmarks3DFileWriter = FaceLandmarksFileWriter(recording: recording, outputType: .landmarks3D)
        else {
            logger.error("Failed to initialize FaceLandmarksPipeline: Recording \(recording.name!) is missing data.")
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
    
    /// Starts the post-processing setup including loading the video assets and creating the CSV output files.
    func startTracking() throws {
        logger.notice("Start processing Recording \(self.recordingName)...")
        
        // Load RGB and depth map video files from saved URLs.
        guard let (videoAsset, depthAsset) = recording.loadAssets(),
              let saveFolder = recording.folderURL
        else {
            throw VisionTrackerProcessorError.fileNotFound
        }
        self.videoAsset = videoAsset
        self.depthAsset = depthAsset
        
        recording.addFiles([
            .landmarks2D: faceLandmarks2DFileWriter.fileURL,
            .landmarks3D: faceLandmarks3DFileWriter.fileURL,
            .info: infoFileWriter.fileURL
        ])
        
        // Write the recording information to file now that totalFrames has been computed.
        // (somewhat abusing the fact that the recording's folder is named using the start time of the recording).
        infoFileWriter.writeInfoRow(startTime: saveFolder.lastPathComponent, totalFrames: Int(recording.totalFrames))
        
        // Try to perform the video tracking.
        try self.performTracking()
    }
    
    /// Tells the pipeline to stop tracking at the start of the next frame.
    ///
    /// All processing will still be completed for the current frame.
    func cancelTracking() {
        logger.notice("Processing cancelled while processing Recording \(self.recordingName).")
        cancelRequested = true
    }
    
    // MARK: Read Video and Perform Tracking
    
    /// Starts reading the recording's video assets and performs face tracking and post-processing at every frame.
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
        
        logger.notice("Processing setup completed successfully. Performing face tracking on Recording \(self.recordingName).")
        
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
            guard !cancelRequested, let videoFrame = videoReader.nextFrame() else {
                break
            }
            
            frames += 1
            
            let videoTime = CMTimeGetSeconds(videoFrame.presentationTimeStamp)
            
            guard let videoImage = CMSampleBufferGetImageBuffer(videoFrame) else {
                logger.error("No image found in video sample.")
                break
            }
            
            // We may run out of depth frames before video frames, but we don't want to break the loop.
            if let depthFrame = nextDepthFrame, let depthImage = nextDepthImage {
                
                let depthTime = CMTimeGetSeconds(depthFrame.presentationTimeStamp)
                // If there is a dropped frame, then the videos will become misaligned and it will never record the depth data, so we must compare the timestamps
                // This doesn't always work if many frames are dropped early, so we may need another way to check (frame index?)
                switch (videoTime, depthTime) {
                case let (videoTime, depthTime) where videoTime < depthTime:
                    // Video frame is before depth frame, so don't send the depth data to record
                    try trackAndRecord(video: videoImage, depth: nil, frames, videoTime)
                    // Start at beginning of next loop iteration without getting a new depth frame from the reader
//                    print("<")
                    continue
                case let (videoTime, depthTime) where videoTime == depthTime:
                    // Frames match, so send the depth data to be recorded
                    try trackAndRecord(video: videoImage, depth: depthImage, frames, videoTime)
//                    print("=")
                //case let (videoTime, depthTime) where videoTime > depthTime:
                default:
                    // Video frame is after depth frame, so don't send the depth data
//                    print(">")
                    try trackAndRecord(video: videoImage, depth: nil, frames, videoTime)
                }
            } else {
                // No more depth data
//                print("No more depth data frames found")
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
    private func processFace(
        _ faceObservation: VNFaceObservation?,
        with depthDataMap: CVPixelBuffer?
    ) -> (
        boundingBox: CGRect,
        landmarks2D: [vector_float3],
        landmarks3D: [vector_float3]
    ) {
        
        // In case the face is lost in the middle of collecting data,
        // this prevents empty or nil-valued cells in the file so it can still be parsed later.
        var boundingBox = CGRect.zero
        var landmarks2D = Array(repeating: vector_float3(repeating: 0.0), count: processorSettings.numLandmarks)
        var landmarks3D = Array(repeating: vector_float3(repeating: 0.0), count: processorSettings.numLandmarks)
        
        if let faceObservation = faceObservation {
            // Get face bounding box in RGB image coordinates.
            boundingBox = VNImageRectForNormalizedRect(
                faceObservation.boundingBox,
                Int(processorSettings.videoResolution.width),
                Int(processorSettings.videoResolution.height))
            
            if let landmarks = faceObservation.landmarks?.allPoints {
                
                // TODO: TEST THIS, may need VNImagePointForFaceLandmarkPoint() instead (compare).
//                let landmarkPointsInVideoImage = landmarks.pointsInImage(imageSize: processorSettings.videoResolution)
                let landmarkPointsInVideoImage = landmarks.normalizedPoints.map { landmarkPoint in
                    VNImagePointForFaceLandmarkPoint(
                        vector_float2(landmarkPoint),
                        faceObservation.boundingBox,
                        Int(processorSettings.videoResolution.width),
                        Int(processorSettings.videoResolution.height))
                }
                landmarks2D = landmarkPointsInVideoImage.map { vector_float3(vector_float2($0), 0.0) }
                
//                let landmarkPointsInDepthImage = landmarks.pointsInImage(imageSize: processorSettings.depthResolution)
                let landmarkPointsInDepthImage = landmarks.normalizedPoints.map { landmarkPoint in
                    VNImagePointForFaceLandmarkPoint(
                        vector_float2(landmarkPoint),
                        faceObservation.boundingBox,
                        Int(processorSettings.depthResolution.width),
                        Int(processorSettings.depthResolution.height))
                }
                if let depthDataMap = depthDataMap,
                   let correctedDepthMap = rectifyDepthMapGPU(depthDataMap: depthDataMap),
                   let correctedLandmarks = rectifyLandmarks(landmarks: landmarkPointsInDepthImage) {
                    
                    let correctedLandmarkVectors = correctedLandmarks.map { vector_float2($0) }
                    
                    // If any of the landmarks fails to be processed, it discards the rest and returns just as if no depth was given.
                    if let landmarkPointCloud = computePointCloud(landmarks: correctedLandmarkVectors, depthMap: correctedDepthMap) {
                        
                        landmarks3D = landmarkPointCloud
                        
                        for index in 0..<landmarks2D.count {
                            landmarks2D[index].z = landmarkPointCloud[index].z
                        }
                    }
                }
            }
        }
        return (boundingBox, landmarks2D, landmarks3D)
    }
    
    /// Write face observation results to file if collecting data.
    private func recordLandmarks(of faceObservation: VNFaceObservation, with depthDataMap: CVPixelBuffer?, frame: Int, timeStamp: Float64) {
        
        // Perform data collection in background queue so that it does not hold up the UI.
        let (boundingBox, landmarks2D, landmarks3D) = processFace(faceObservation, with: depthDataMap)
        faceLandmarks2DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks2D)
        faceLandmarks3DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks3D)
    }
}

// MARK: Lens Distortion Correction
extension FaceLandmarksPipeline {
    
    private func computePointCloud(landmarks: [vector_float2], depthMap: CVPixelBuffer) -> [vector_float3]? {
        if !pointCloudProcessor.isPrepared {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: depthMap,
                formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                pointCloudProcessor.prepare(with: unwrappedDepthFormatDescription)
            }
        }
        let pointCloud = pointCloudProcessor.render(landmarks: landmarks, depthFrame: depthMap)
        if pointCloud == nil {
            logger.error("Metal point cloud processor failed to render point cloud.")
        }
        return pointCloud
    }
    
    /// Rectify the depth data map from lens-distorted to rectilinear coordinate space.
    private func rectifyDepthMapGPU(depthDataMap: CVPixelBuffer) -> CVPixelBuffer? {
        if !lensDistortionCorrectionProcessor.isPrepared {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: depthDataMap,
                formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                lensDistortionCorrectionProcessor.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 3)
            }
        }
        let correctedDepthMap = lensDistortionCorrectionProcessor.render(pixelBuffer: depthDataMap)
        if correctedDepthMap == nil {
            logger.error("Metal lens distortion correction processor failed to render depth map.")
        }
        return correctedDepthMap
    }
    
    private func rectifyLandmarks(landmarks: [CGPoint]) -> [CGPoint]? {
        // Get camera instrinsics
        guard let cameraCalibrationData = (processorSettings.decodedCameraCalibrationData ?? processorSettings.cameraCalibrationData) as? CameraCalibrationDataProtocol,
              let lookupTable = cameraCalibrationData.inverseLensDistortionLookupTable
        else {
            logger.error("FaceLandmarksPipeline.rectifyLandmarks: Could not find camera calibration data")
            return nil
        }
        let referenceDimensions: CGSize = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        let opticalCenter: CGPoint = cameraCalibrationData.lensDistortionCenter
        
        let ratio: Float = Float(referenceDimensions.width) / Float(processorSettings.depthResolution.width)
        let scaledOpticalCenter = CGPoint(x: opticalCenter.x / CGFloat(ratio), y: opticalCenter.y / CGFloat(ratio))
        
        let outputPoint = landmarks.map { lensDistortionPointForPoint($0, lookupTable, scaledOpticalCenter, processorSettings.depthResolution) }
        
        return outputPoint
    }
}
