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
    
    // File Writers
    private var faceLandmarks2DFileWriter: FaceLandmarksFileWriter
    private var faceLandmarks3DFileWriter: FaceLandmarksFileWriter
    private var infoFileWriter: InfoFileWriter
    
    // Pixel buffer pool for concurrent tracking & file writing
    private var depthMapPixelBufferPool: CVPixelBufferPool?
    
    // Video readers and assets
    private var videoReader: VideoReader?
    private var depthReader: VideoReader?
    private var videoAsset: AVAsset?
    private var depthAsset: AVAsset?
    
    private var cancelRequested = false
    
    init?(recording: Recording) {
        guard let processorSettings = recording.processorSettings else {
            print("Failed to start tracking: processor settings not found")
            return nil
        }
        self.processorSettings = processorSettings
        self.recording = recording
        self.visionTrackerProcessor = LandmarksTrackerProcessor(processorSettings: processorSettings)
        self.pointCloudProcessor = PointCloudProcessor(settings: processorSettings)
        self.faceLandmarks2DFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
        self.faceLandmarks3DFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
        self.infoFileWriter = InfoFileWriter(recording: recording, processorSettings: processorSettings)
    }
    
    // MARK: - Pipeline Setup
    
    func startTracking() throws {
        // Load RGB and depth map video files from saved URLs
        guard let (videoAsset, depthAsset) = self.loadAssets(from: recording),
              let saveFolder = recording.folderURL
        else {
            throw VisionTrackerProcessorError.fileNotFound
        }
        self.videoAsset = videoAsset
        self.depthAsset = depthAsset
        
        // Create the landmarks csv files and save in recordings data source
        
        guard let landmarks2DURL = self.createFileURL(in: saveFolder, nameLabel: OutputType.landmarks2D.rawValue, fileType: "csv") else {
            print("Failed to create landmarks2D file")
            return
        }
        guard let landmarks3DURL = self.createFileURL(in: saveFolder, nameLabel: OutputType.landmarks3D.rawValue, fileType: "csv") else {
            print("Failed to create landmarks2D file")
            return
        }
        guard let infoURL = self.createFileURL(in: saveFolder, nameLabel: OutputType.info.rawValue, fileType: "csv") else {
            print("Failed to create landmarks2D file")
            return
        }
        self.recording.addFiles(newFiles: [OutputType.landmarks2D: landmarks2DURL,
                                           OutputType.landmarks3D: landmarks3DURL,
                                           OutputType.info: infoURL])
        
        
        // Prepare the landmarks file writers
        self.faceLandmarks2DFileWriter.prepare(saveURL: landmarks2DURL)
        self.faceLandmarks3DFileWriter.prepare(saveURL: landmarks3DURL)
        self.infoFileWriter.prepare(saveURL: infoURL)
        self.infoFileWriter.createInfoRow(startTime: saveFolder.lastPathComponent, totalFrames: Int(recording.totalFrames))
        
        // Try to perform the video tracking
        try self.performTracking()
    }
    
    /// Loads the video assets for the inputted recording.
    private func loadAssets(from recording: Recording) -> (AVAsset, AVAsset)? {
        
        guard let videoFile = recording.files?.first(where: { ($0 as? OutputFile)?.outputType == OutputType.video.rawValue }) as? OutputFile,
              let depthFile = recording.files?.first(where: { ($0 as? OutputFile)?.outputType == OutputType.depth.rawValue }) as? OutputFile,
              let videoURL = videoFile.fileURL,
              let depthURL = depthFile.fileURL else {
            print("Failed to access saved files")
            return nil
        }
        
        if FileManager.default.fileExists(atPath: videoURL.path) {
            recording.totalFrames = Int64(getNumberOfFrames(videoURL))
        } else {
            print("File does not exist at specified URL: \(videoURL.path)")
            return nil
        }
        let videoAsset = AVAsset(url: videoURL)
        let depthAsset = AVAsset(url: depthURL)
        return (videoAsset, depthAsset)
    }
    
    // MARK: Read Video and Perform Tracking
    func performTracking() throws {
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
        
        // Create pixel buffer pool for depth map rectification
        if depthMapPixelBufferPool == nil, let depthImage = nextDepthImage {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: depthImage,
                                                         formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                (depthMapPixelBufferPool, _, _) = allocateOutputBufferPool(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 3)
            }
        }
        if depthMapPixelBufferPool == nil {
            throw VisionTrackerProcessorError.readerInitializationFailed
        }
        
        func trackAndRecord(video: CVPixelBuffer, depth: CVPixelBuffer?, _ frame: Int, _ timeStamp: Float64) throws {
            try visionTrackerProcessor.performVisionRequests(on: video, orientation: videoReader.orientation, completion: { faceObservation in
                self.recordLandmarks(of: faceObservation, with: depth, frame: frame, timeStamp: timeStamp)
                // Display the frame counter in the UI on the main thread
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
    
    func cancelTracking() {
        cancelRequested = true
    }
    
    // MARK: - Landmarks Depth Processing
    
    /// Combines a face observation and depth data to produce a bounding box and face landmarks in 3D space.
    ///
    /// If no depth is provided, it returns the 2D landmarks in image coordinates.
    /// If no landmarks are provided, it returns just the bounding box.
    /// If no face observation is provided, it returns all zeros.
    func processFace(_ faceObservation: VNFaceObservation?, with depthDataMap: CVPixelBuffer?) -> (CGRect, [vector_float3], [vector_float3]?) {
        
        // In case the face is lost in the middle of collecting data, this prevents empty or nil-valued cells in the file so it can still be parsed later.
        var boundingBox = CGRect.zero
        var landmarks2D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        var landmarks3D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        
        if let faceObservation = faceObservation {
            // Get face bounding box in RGB image coordinates.
            boundingBox = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(processorSettings.videoResolution.width), Int(processorSettings.videoResolution.height))
            
            if let landmarks = faceObservation.landmarks?.allPoints {
                
                if let depthDataMap = depthDataMap, let correctedDepthMap = rectifyDepthDataMap(depthDataMap: depthDataMap) {
                    
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
    
    /// Rectify the depth data map from lens-distorted to rectilinear coordinate space.
    private func rectifyDepthDataMap(depthDataMap: CVPixelBuffer) -> CVPixelBuffer? {
        
        // Get camera instrinsics
        guard let cameraCalibrationData = (processorSettings.decodedCameraCalibrationData ?? processorSettings.cameraCalibrationData) as? CameraCalibrationDataProtocol,
              let lookupTable = cameraCalibrationData.inverseLensDistortionLookupTable else {
            print("FaceLandmarksPipeline.rectifyDepthDataMap: Could not find camera calibration data")
            return nil
        }
        let referenceDimensions: CGSize = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        let opticalCenter: CGPoint = cameraCalibrationData.lensDistortionCenter
        
        let ratio: Float = Float(referenceDimensions.width) / Float(CVPixelBufferGetWidth(depthDataMap))
        let scaledOpticalCenter = CGPoint(x: opticalCenter.x / CGFloat(ratio), y: opticalCenter.y / CGFloat(ratio))
        
        // Get depth stream resolutions and pixel format
        let depthMapWidth = CVPixelBufferGetWidth(depthDataMap)
        let depthMapHeight = CVPixelBufferGetHeight(depthDataMap)
        let depthMapSize = CGSize(width: depthMapWidth, height: depthMapHeight)
        
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, depthMapPixelBufferPool!, &newPixelBuffer)
        guard let outputBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool)")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let inputBytesPerRow = CVPixelBufferGetBytesPerRow(depthDataMap)
        guard let inputBaseAddress = CVPixelBufferGetBaseAddress(depthDataMap) else {
            print("input pointer failed")
            return nil
        }
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else {
            print("output pointer failed")
            return nil
        }
        
        // Loop over all output pixels
        for y in 0..<depthMapHeight {
            // Create pointer to output buffer
            let outputRowData = outputBaseAddress + y * outputBytesPerRow
            let outputData = UnsafeMutableBufferPointer(start: outputRowData.assumingMemoryBound(to: Float32.self), count: depthMapWidth)
            
            for x in 0..<depthMapWidth {
                // For each output pixel, do inverse distortion transformation and clamp the points within the bounds of the buffer
                let distortedPoint = CGPoint(x: x, y: y)
                var correctedPoint = lensDistortionPointForPoint(distortedPoint, lookupTable, scaledOpticalCenter, depthMapSize)
                correctedPoint.clamp(bounds: depthMapSize)
                
                // Create pointer to input buffer
                let inputRowData = inputBaseAddress + Int(correctedPoint.y) * inputBytesPerRow
                let inputData = UnsafeBufferPointer(start: inputRowData.assumingMemoryBound(to: Float32.self), count: depthMapWidth)
                
                // Sample pixel value from input buffer and pull into output buffer
                let pixelValue = inputData[Int(correctedPoint.x)]
                outputData[x] = pixelValue
            }
        }
        CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
        CVPixelBufferUnlockBaseAddress(outputBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return outputBuffer
    }
    
    /// Write face observation results to file if collecting data.
    func recordLandmarks(of faceObservation: VNFaceObservation, with depthDataMap: CVPixelBuffer?, frame: Int, timeStamp: Float64) {
        
        // Perform data collection in background queue so that it does not hold up the UI.
        let (boundingBox, landmarks2D, landmarks3D) = processFace(faceObservation, with: depthDataMap)
        faceLandmarks2DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks2D)
        if let landmarks3D = landmarks3D {
            faceLandmarks3DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks3D)
        }
    }
}
