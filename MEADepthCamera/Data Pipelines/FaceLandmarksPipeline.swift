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
    
    private(set) var faceLandmarksFileWriter: FaceLandmarksFileWriter
    
    private let savedRecordingsDataSource: SavedRecordingsDataSource
    
    // Depth conversion
    let videoGrayscaleConverter = GrayscaleToDepthConverter()
    
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
        self.faceLandmarksFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
        self.savedRecordingsDataSource = savedRecordingsDataSource
        self.cameraViewController?.faceLandmarksPipeline = self
    }
    
    // MARK: - Pipeline Setup
    
    func startTracking() {
        visionTrackingQueue.async {
            // Load RGB and depth map video files from saved URLs
            guard let (landmarksURL, videoAsset, depthAsset) = self.loadAssets() else {
                return
            }
            self.videoAsset = videoAsset
            self.depthAsset = depthAsset

            self.faceLandmarksFileWriter.prepare(saveURL: landmarksURL)
            
            // Initialize Vision tracker processor
            self.visionTrackerProcessor = LandmarksTrackerProcessor(processorSettings: self.processorSettings)
            do {
                try self.performTracking()
            } catch {
                self.cameraViewController?.handleTrackerError(error)
            }
        }
    }
    
    private func loadAssets() -> (URL, AVAsset, AVAsset)? {
        guard let lastSavedRecording = savedRecordingsDataSource.savedRecordings.last else {
            print("Last saved recording not found")
            return nil
        }
        let folderURL = lastSavedRecording.folderURL
        guard let videoFile = lastSavedRecording.savedFiles.first(where: { $0.outputType == OutputType.video }),
              let depthFile = lastSavedRecording.savedFiles.first(where: { $0.outputType == OutputType.depth }),
              let landmarksFile = lastSavedRecording.savedFiles.first(where: { $0.outputType == OutputType.landmarks }) else {
            print("Failed to access saved files")
            return nil
        }
        let videoURL = folderURL.appendingPathComponent(videoFile.lastPathComponent)
        let depthURL = folderURL.appendingPathComponent(depthFile.lastPathComponent)
        let landmarksURL = folderURL.appendingPathComponent(landmarksFile.lastPathComponent)
        if FileManager.default.fileExists(atPath: videoURL.path) {
            totalFrames = Int(getNumberOfFrames(videoURL))
            print(totalFrames!)
        } else {
            print("File does not exist at specified URL")
            return nil
        }
        let videoAsset = AVAsset(url: videoURL)
        let depthAsset = AVAsset(url: depthURL)
        return (landmarksURL, videoAsset, depthAsset)
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
        
        var frames = 1
        
        var nextDepthFrame: CMSampleBuffer? = depthReader.nextFrame()
        var nextDepthImage: CVPixelBuffer?
        if let depthFrame = nextDepthFrame {
            nextDepthImage = CMSampleBufferGetImageBuffer(depthFrame)
        }
        
        // Prepare the depth to grayscale converter and depth map file configuration
        if !self.videoGrayscaleConverter.isPrepared, let depthImage = nextDepthImage {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: depthImage,
                                                         formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                self.videoGrayscaleConverter.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 2)
            }
        }
        
        func trackAndRecord(video: CVPixelBuffer, depth: CVPixelBuffer?, _ frame: Int, _ timeStamp: Float64) throws {
            try visionTrackerProcessor?.performVisionRequests(on: video, completion: { faceObservation in
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
            if let depthFrame = nextDepthFrame, var depthImage = nextDepthImage {
                
                // Convert the depth image from grayscale RGB to depth float, if we haven't already
                if CVPixelBufferGetPixelFormatType(depthImage) != kCVPixelFormatType_DepthFloat32 {
                    if let convertedDepthImage = videoGrayscaleConverter.render(pixelBuffer: depthImage) {
                        depthImage = convertedDepthImage
                    } else {
                        print("Failed to convert from grayscale to depth")
                    }
                }
                
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
                    //print("No depth data found. Returning 2D landmarks in RGB image coordinates.")
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
    
    func recordLandmarks(of faceObservation: VNFaceObservation, with depthDataMap: CVPixelBuffer?, frame: Int, timeStamp: Float64) {
        // Write face observation results to file if collecting data.
        // Perform data collection in background queue so that it does not hold up the UI.
        
        let (boundingBox, landmarks) = processFace(faceObservation, with: depthDataMap)
        faceLandmarksFileWriter.writeToCSV(frame: frame, timeStamp: timeStamp, boundingBox: boundingBox, landmarks: landmarks)
        
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
