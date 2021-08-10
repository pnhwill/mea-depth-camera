//
//  FaceLandmarksPipeline.swift
//  MEADepthCamera
//
//  Created by Will on 7/26/21.
//

import AVFoundation
import Vision

class FaceLandmarksPipeline: DataPipeline {
    
    // Weak reference to camera view controller
    private weak var cameraViewController: CameraViewController?
    
    private var processorSettings: ProcessorSettings
    
    var visionTrackerProcessor: LandmarksTrackerProcessor?
    
    // Point cloud Metal renderer with compute kernel
    private var pointCloudProcessor: PointCloudProcessor
    
    private(set) var faceLandmarks2DFileWriter: FaceLandmarksFileWriter
    private(set) var faceLandmarks3DFileWriter: FaceLandmarksFileWriter
    private(set) var infoFileWriter: InfoFileWriter
    
    private let savedRecordingsDataSource: SavedRecordingsDataSource
    
    var depthMapPixelBufferPool: CVPixelBufferPool?
    
    let visionTrackingQueue = DispatchQueue(label: "vision tracking queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    var totalFrames: Int?
    
    private var videoAsset: AVAsset?
    private var videoReader: VideoReader?
    private var depthAsset: AVAsset?
    private var depthReader: VideoReader?
    
    private var cancelRequested = false
    
    init(cameraViewController: CameraViewController, processorSettings: ProcessorSettings, savedRecordingsDataSource: SavedRecordingsDataSource) {
        self.cameraViewController = cameraViewController
        self.processorSettings = processorSettings
        self.pointCloudProcessor = PointCloudProcessor(settings: processorSettings)
        self.faceLandmarks2DFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
        self.faceLandmarks3DFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
        self.infoFileWriter = InfoFileWriter(processorSettings: processorSettings)
        self.savedRecordingsDataSource = savedRecordingsDataSource
        self.cameraViewController?.faceLandmarksPipeline = self
    }
    
    // MARK: - Pipeline Setup
    
    func startTracking() {
        visionTrackingQueue.async {
            guard var lastSavedRecording = self.savedRecordingsDataSource.savedRecordings.last else {
                print("Last saved recording not found")
                return
            }
            // Load RGB and depth map video files from saved URLs
            guard let (videoAsset, depthAsset) = self.loadAssets(from: lastSavedRecording) else {
                return
            }
            self.videoAsset = videoAsset
            self.depthAsset = depthAsset
            
            // Create the landmarks csv files and save in recordings data source
            let saveFolder = lastSavedRecording.folderURL
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
            self.savedRecordingsDataSource.addFilesToSavedRecording(&lastSavedRecording, newFiles: [OutputType.landmarks2D: landmarks2DURL,
                                                                                                    OutputType.landmarks3D: landmarks3DURL,
                                                                                                    OutputType.info: infoURL])
            
            // Prepare the landmarks file writers
            self.faceLandmarks2DFileWriter.prepare(saveURL: landmarks2DURL)
            self.faceLandmarks3DFileWriter.prepare(saveURL: landmarks3DURL)
            self.infoFileWriter.prepare(saveURL: infoURL)
            if let totalFrames = self.totalFrames {
                self.infoFileWriter.createInfoRow(startTime: saveFolder.lastPathComponent, totalFrames: totalFrames)
            }
            
            // Initialize Vision tracker processor
            self.visionTrackerProcessor = LandmarksTrackerProcessor(processorSettings: self.processorSettings)
            do {
                try self.performTracking()
            } catch {
                self.cameraViewController?.handleTrackerError(error)
            }
        }
    }
    
    private func loadAssets(from savedRecording: SavedRecording) -> (AVAsset, AVAsset)? {

        let folderURL = savedRecording.folderURL
        guard let videoFile = savedRecording.savedFiles.first(where: { $0.outputType == OutputType.video }),
              let depthFile = savedRecording.savedFiles.first(where: { $0.outputType == OutputType.depth }) else {
            print("Failed to access saved files")
            return nil
        }
        let videoURL = folderURL.appendingPathComponent(videoFile.lastPathComponent)
        let depthURL = folderURL.appendingPathComponent(depthFile.lastPathComponent)
        if FileManager.default.fileExists(atPath: videoURL.path) {
            totalFrames = Int(getNumberOfFrames(videoURL))
            print(totalFrames!)
        } else {
            print("File does not exist at specified URL")
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
        
        guard (visionTrackerProcessor?.prepareVisionRequest()) != nil else {
            throw VisionTrackerProcessorError.faceTrackingFailed
        }
        
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
            try visionTrackerProcessor?.performVisionRequests(on: video, orientation: videoReader.orientation, completion: { faceObservation in
                self.recordLandmarks(of: faceObservation, with: depth, frame: frame, timeStamp: timeStamp)
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
                print("No depth data found")
                try trackAndRecord(video: videoImage, depth: nil, frames, videoTime)
            }
            
            // Get the next depth frame from the reader
            nextDepthFrame = depthReader.nextFrame()
            if let depthFrame = nextDepthFrame {
                nextDepthImage = CMSampleBufferGetImageBuffer(depthFrame)
            }
            
        }
        
        didFinishTracking()
    }
    
    func cancelTracking() {
        cancelRequested = true
    }
    
    // MARK: - Methods to get depth data for landmarks
    
    func processFace(_ faceObservation: VNFaceObservation?, with depthDataMap: CVPixelBuffer?) -> (CGRect, [vector_float3], [vector_float3]?) {
        // This method combines a face observation and depth data to produce a bounding box and face landmarks in 3D space.
        // If no depth is provided, it returns the 2D landmarks in image coordinates.
        // If no landmarks are provided, it returns just the bounding box.
        // If no face observation is provided, it returns all zeros.
        
        // In case the face is lost in the middle of collecting data, this prevents empty or nil-valued cells in the file so it can still be parsed later
        var boundingBox = CGRect.zero
        var landmarks2D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        var landmarks3D = Array(repeating: simd_make_float3(0.0, 0.0, 0.0), count: processorSettings.numLandmarks)
        
        if let faceObservation = faceObservation {
            // Get face bounding box in RGB image coordinates
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
                        // If any of the landmarks fails to be processed, it discards the rest and returns just as if no depth was given
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
        guard let referenceDimensions: CGSize = processorSettings.cameraCalibrationData?.intrinsicMatrixReferenceDimensions,
              let opticalCenter: CGPoint = processorSettings.cameraCalibrationData?.lensDistortionCenter,
              let lookupTable = processorSettings.cameraCalibrationData?.inverseLensDistortionLookupTable else {
            print("Could not find camera calibration data")
            return nil
        }
        let ratio: Float = Float(referenceDimensions.width) / Float(processorSettings.depthResolution.width)
        let scaledOpticalCenter = CGPoint(x: opticalCenter.x / CGFloat(ratio), y: opticalCenter.y / CGFloat(ratio))
        
        let outputPoint = lensDistortionPointForPoint(landmark, lookupTable, scaledOpticalCenter, processorSettings.depthResolution)
        
        return outputPoint
    }
    
    private func rectifyDepthDataMap(depthDataMap: CVPixelBuffer) -> CVPixelBuffer? {
        // Method to rectify the depth data map from lens-distorted to rectilinear coordinate space
        
        // Get camera instrinsics
        guard let referenceDimensions: CGSize = processorSettings.cameraCalibrationData?.intrinsicMatrixReferenceDimensions,
              let opticalCenter: CGPoint = processorSettings.cameraCalibrationData?.lensDistortionCenter,
              let lookupTable = processorSettings.cameraCalibrationData?.inverseLensDistortionLookupTable else {
            print("Could not find camera calibration data")
            return nil
        }
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
    
    func recordLandmarks(of faceObservation: VNFaceObservation, with depthDataMap: CVPixelBuffer?, frame: Int, timeStamp: Float64) {
        // Write face observation results to file if collecting data.
        // Perform data collection in background queue so that it does not hold up the UI.
        
        let (boundingBox, landmarks2D, landmarks3D) = processFace(faceObservation, with: depthDataMap)
        faceLandmarks2DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks2D)
        if let landmarks3D = landmarks3D {
            faceLandmarks3DFileWriter.writeRowData(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks3D)
        }
        
        // Display the frame counter on the UI
        cameraViewController?.displayFrameCounter(frame)
    }
    
    func didFinishTracking() {
        faceLandmarks2DFileWriter.reset()
        faceLandmarks3DFileWriter.reset()
        depthMapPixelBufferPool = nil
        DispatchQueue.main.async {
            self.cameraViewController?.trackingState = .stopped
            self.cameraViewController?.processingMode = .record
        }
    }
}
