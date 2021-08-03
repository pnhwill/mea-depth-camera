//
//  CaptureDataOutputProcessor.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation
import Combine
import Vision

class DataOutputProcessor: NSObject {
    
    var processorSettings: ProcessorSettings?
    
    // Weak reference to camera view controller
    private weak var cameraViewController: CameraViewController?
    
    // Capture session manager
    private weak var sessionManager: CaptureSessionManager!
    
    // Preview view
    private weak var previewView: PreviewMetalView?
    
    // Data outputs
    private unowned var videoDataOutput: AVCaptureVideoDataOutput
    private unowned var depthDataOutput: AVCaptureDepthDataOutput
    //private unowned var metadataOutput: AVCaptureMetadataOutput
    private unowned var audioDataOutput: AVCaptureAudioDataOutput
    
    // Recording
    var recordingState = RecordingState.idle
    
    // Depth processing
    private let videoDepthConverter = DepthToGrayscaleConverter()
    
    // Vision requests
    private(set) var visionProcessor: VisionTrackerProcessor?
    var faceProcessor: FaceLandmarksProcessor?

    // Depth processing (needs removing after moving record function)
    var depthData: AVDepthData?
    
    // AV file writing
    
    private var videoFileWriter: VideoFileWriter<FileWriterSubject>?
    private var audioFileWriter: AudioFileWriter<FileWriterSubject>?
    private var depthMapFileWriter: DepthMapFileWriter<FileWriterSubject>?
    
    private struct FileWriterSettings {
        let fileExtensions: [AVFileType: String] = [.mov: "mov", .wav: "wav"]
        
        var configuration: FileConfiguration?
        let fileType: AVFileType
        let fileExtension: String
        
        init(fileType: AVFileType) {
            self.fileType = fileType
            self.fileExtension = fileExtensions[fileType]!
        }
    }
    
    private var videoFileSettings = FileWriterSettings(fileType: .mov)
    private var audioFileSettings = FileWriterSettings(fileType: .wav)
    private var depthMapFileSettings = FileWriterSettings(fileType: .mov)
    
    var faceLandmarksFileWriter: FaceLandmarksFileWriter?
    
    // Subjects and subscribers
    typealias FileWriterSubject = PassthroughSubject<WriteState, Error>
    var videoWriterSubject: FileWriterSubject?
    var audioWriterSubject: FileWriterSubject?
    var depthWriterSubject: FileWriterSubject?
    var landmarksWriterSubject: FileWriterSubject?
    
    var fileWritingDone: AnyCancellable?
    
    init(sessionManager: CaptureSessionManager, cameraViewController: CameraViewController) {
        self.sessionManager = sessionManager
        self.cameraViewController = cameraViewController
        self.videoDataOutput = sessionManager.videoDataOutput
        self.depthDataOutput = sessionManager.depthDataOutput
        self.audioDataOutput = sessionManager.audioDataOutput
    }
    
    // MARK: - Data Pipeline Setup
    func configureProcessors() {
        self.visionProcessor = VisionTrackerProcessor()
        self.visionProcessor?.delegate = self
        //self.visionTrackingQueue.async {
            self.visionProcessor?.prepareVisionRequest()
        //}
        
        // Get source media formats
        guard let videoFormat = sessionManager.videoFormatDescription, let depthFormat = sessionManager.depthDataFormatDescription else {
            print("Failed to retrieve source media format descriptions")
            return
        }
        
        // Initialize video file writer configuration
        let videoSettingsForVideo = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: videoFileSettings.fileType)
        let audioSettingsForVideo = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: videoFileSettings.fileType)
        guard let videoTransform = self.createVideoTransform(for: videoDataOutput) else {
            print("Could not create video transform")
            return
        }
        videoFileSettings.configuration = VideoFileConfiguration(fileType: videoFileSettings.fileType,
                                                                 videoSettings: videoSettingsForVideo,
                                                                 audioSettings: audioSettingsForVideo,
                                                                 transform: videoTransform,
                                                                 videoFormat: videoFormat)
        
        // Initialize audio file writer configuration
        let audioSettingsForAudio = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: audioFileSettings.fileType)
        audioFileSettings.configuration = AudioFileConfiguration(fileType: audioFileSettings.fileType,
                                                                 audioSettings: audioSettingsForAudio)
        
        // Initialize depth map file writer configuration
        let videoSettingsForDepthMap = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: depthMapFileSettings.fileType)
        depthMapFileSettings.configuration = DepthMapFileConfiguration(fileType: depthMapFileSettings.fileType,
                                                                       videoSettings: videoSettingsForDepthMap,
                                                                       transform: videoTransform,
                                                                       depthDataFormat: depthFormat)
        
        // Initialize landmarks file writer
        guard let processorSettings = processorSettings else {
            print("No processor settings found, cannot initialize face landmarks processor.")
            return
        }
        
        faceLandmarksFileWriter = FaceLandmarksFileWriter(numLandmarks: processorSettings.numLandmarks)
        //cameraViewController?.faceLandmarksFileWriter = faceLandmarksFileWriter
        faceProcessor = FaceLandmarksProcessor(settings: processorSettings)
        //cameraViewController?.faceProcessor = faceProcessor
    }
    
    // MARK: - Data Processing Methods
    func processDepth(depthData: AVDepthData, timestamp: CMTime) {
        
        if recordingState != .idle {
            
            // Ensure depth data is of the correct type
            //let depthDataType = kCVPixelFormatType_DepthFloat32
            let depthDataType = kCVPixelFormatType_DisparityFloat32
            var convertedDepth: AVDepthData
            
            if depthData.depthDataType != depthDataType {
                convertedDepth = depthData.converting(toDepthDataType: depthDataType)
            } else {
                convertedDepth = depthData
            }
            
            DispatchQueue.main.async {
                self.depthData = convertedDepth
            }
            
            //convertedDepth.applyingExifOrientation(exifOrientationForCurrentDeviceOrientation())
            //print(convertedDepth.depthDataQuality.rawValue)
            /*
            guard renderingEnabled else {
                return
            }
            */
            
            if !videoDepthConverter.isPrepared {
                var depthFormatDescription: CMFormatDescription?
                CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                             imageBuffer: convertedDepth.depthDataMap,
                                                             formatDescriptionOut: &depthFormatDescription)
                if let unwrappedDepthFormatDescription = depthFormatDescription {
                    videoDepthConverter.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 2)
                }
            }
            
            guard let depthPixelBuffer = videoDepthConverter.render(pixelBuffer: convertedDepth.depthDataMap) else {
                print("Unable to process depth")
                return
            }
            
            writeDepthMapToFile(depthMap: depthPixelBuffer, timeStamp: timestamp)
        }
        
    }
    
    func processVideo(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        
        let output = videoDataOutput
        if recordingState != .idle {
            writeOutputToFileOld(output, sampleBuffer: sampleBuffer)
        }
        
        //autoreleasepool {
        guard let visionProcessor = self.visionProcessor else {
            print("Vision tracking processor not found.")
            return
        }
        
        var attachmentMode = kCMAttachmentMode_ShouldPropagate
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: &attachmentMode)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        /*
        if !visionProcessor.isPrepared {
         guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
         }
            /*
             outputRetainedBufferCountHint is the number of pixel buffers the renderer retains.
             This value informs the renderer how to size its buffer pool and how many pixel buffers to preallocate.
             Allow 3 frames of latency to cover the dispatch_async call.
             */
            visionProcessor.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
        }
        
        guard let pixelBufferCopy = visionProcessor.copyPixelBuffer(inputBuffer: pixelBuffer) else {
            print("Failed to copy pixel buffer.")
            return
        }
        */
        
        //visionTrackingQueue.async {
        visionProcessor.performVisionRequests(on: pixelBuffer, cameraIntrinsicData: cameraIntrinsicData as? AVCameraCalibrationData)
        //}
        //}
        
        // Change this to only update every other frame if necessary
        if cameraViewController!.renderingEnabled {
            cameraViewController!.previewView.pixelBuffer = pixelBuffer
        }
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        
        let output = audioDataOutput
        if recordingState != .idle {
            writeOutputToFileOld(output, sampleBuffer: sampleBuffer)
        }
        
    }
    
    // MARK: - Data Recording
    
    func startRecording() {
        // Create folder for all data files
        guard let saveFolder = createFolder() else {
            print("Failed to create save folder")
            return
        }
        guard let audioURL = createFileURL(in: saveFolder, nameLabel: "audio", fileType: audioFileSettings.fileExtension) else {
            print("Failed to create audio file")
            return
        }
        guard let videoURL = createFileURL(in: saveFolder, nameLabel: "video", fileType: videoFileSettings.fileExtension) else {
            print("Failed to create video file")
            return
        }
        guard let depthMapURL = createFileURL(in: saveFolder, nameLabel: "depth", fileType: depthMapFileSettings.fileExtension) else {
            print("Failed to create depth map file")
            return
        }
        guard let landmarksURL = createFileURL(in: saveFolder, nameLabel: "landmarks", fileType: "csv") else {
            print("Failed to create landmarks file")
            return
        }
        guard let videoConfiguration = videoFileSettings.configuration,
              let audioConfiguration = audioFileSettings.configuration,
              let depthMapConfiguration = depthMapFileSettings.configuration else {
            print("AV file configurations not found")
            return
        }
        videoWriterSubject = FileWriterSubject()
        audioWriterSubject = FileWriterSubject()
        depthWriterSubject = FileWriterSubject()
        
        do {
            videoFileWriter = try VideoFileWriter(outputURL: videoURL, configuration: videoConfiguration as! VideoFileConfiguration, subject: videoWriterSubject!)
        } catch {
            print("Error creating video file writer: \(error)")
        }
        do {
            audioFileWriter = try AudioFileWriter(outputURL: audioURL, configuration: audioConfiguration as! AudioFileConfiguration, subject: audioWriterSubject!)
        } catch {
            print("Error creating audio file writer: \(error)")
        }
        do {
            depthMapFileWriter = try DepthMapFileWriter(outputURL: depthMapURL, configuration: depthMapConfiguration as! DepthMapFileConfiguration, subject: depthWriterSubject!)
        } catch {
            print("Error creating depth map file writer: \(error)")
        }
        guard (faceLandmarksFileWriter?.startDataCollection(path: landmarksURL)) != nil else {
            print("No face landmarks file writer found, failed to access startDataCollection().")
            return
        }
        
        fileWritingDone = videoWriterSubject!.combineLatest(depthWriterSubject!, audioWriterSubject!)
        .sink(receiveCompletion: { [weak self] completion in
            self?.handleRecordingFinish(completion: completion)
        }, receiveValue: { [weak self] state in
            if state == (.active, .active, .active) {
                self?.recordingState = .recording
            }
        })
        recordingState = .start
    }
    
    func stopRecording() {
        videoFileWriter?.endRecording()
        audioFileWriter?.endRecording()
        depthMapFileWriter?.endRecording()
        faceLandmarksFileWriter?.reset()
        recordingState = .finish
    }
    
    private func handleRecordingFinish(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            // update ui with success
            print("File writing success")
            break
        case .failure(let error):
            // update ui with failure
            print("File writing failure: \(error.localizedDescription)")
            break
        }
        recordingState = .idle
    }

    private func createVideoTransform(for output: AVCaptureOutput) -> CGAffineTransform? {
        guard let connection = output.connection(with: .video) else {
                print("Could not find the camera video connection")
                return nil
        }
        let videoOrientation: AVCaptureVideoOrientation = .portrait
        
        // Compute transforms from the front camera's video orientation to the device's orientation
        let cameraTransform = connection.videoOrientationTransform(relativeTo: videoOrientation)

        return cameraTransform
    }
    
    // MARK: - File Writing
    
    private func createFolder() -> URL? {
        // Get or create documents directory
        var docURL: URL?
        do {
            docURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            print("Error getting documents directory: \(error)")
            return nil
        }
        // Get current datetime and format the folder name
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timeStamp = formatter.string(from: date)
        // Create URL for folder inside documents path
        guard let dataURL = docURL?.appendingPathComponent(timeStamp, isDirectory: true) else {
            print("Failed to append folder name to documents URL")
            return nil
        }
        // Create folder at desired path if it does not already exist
        if !FileManager.default.fileExists(atPath: dataURL.path) {
            do {
                try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating folder in documents directory: \(error.localizedDescription)")
            }
        }
        return dataURL
    }
    
    private func createFileURL(in folderURL: URL, nameLabel: String, fileType: String) -> URL? {
        let folderName = folderURL.lastPathComponent
        let fileName = folderName + "_" + nameLabel
        
        let fileURL = folderURL.appendingPathComponent(fileName).appendingPathExtension(fileType)
        
        return fileURL
    }
    /*
    private func writeOutputToFile<T>(_ output: AVCaptureOutput, data: T) {
    }
    */
    private func writeDepthMapToFile(depthMap: CVPixelBuffer, timeStamp: CMTime) {
        guard let depthMapWriter = depthMapFileWriter else {
            print("No depth map file writer found")
            return
        }
        
        switch recordingState {
        case .start:
            // If this file writer is inactive, start it and change it's state to active
            if depthMapWriter.writeState == .inactive {
                depthMapWriter.start(at: timeStamp)
            }
        case .recording:
            depthMapWriter.writeVideo(depthMap, timeStamp: timeStamp)
        default:
            break
        }
    }
    
    private func writeOutputToFileOld(_ output: AVCaptureOutput, sampleBuffer: CMSampleBuffer) {
        guard let videoWriter = videoFileWriter else {
            print("No video file writer found")
            return
        }
        guard let audioWriter = audioFileWriter else {
            print("No audio file writer found")
            return
        }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        switch recordingState {
        case .start:
            // If these file writers are inactive, start them and change their state to active
            if videoWriter.writeState == .inactive {
                videoWriter.start(at: presentationTime)
            }
            if audioWriter.writeState == .inactive {
                audioWriter.start(at: presentationTime)
            }
            //fallthrough
        case .recording:
            // Alternatively we could check the connection instead, but since there's just one connection to each output this is equivalent
            if output === videoDataOutput {
                videoWriter.writeVideo(sampleBuffer)
            } else if output === audioDataOutput {
                videoWriter.writeAudio(sampleBuffer)
                audioWriter.writeAudio(sampleBuffer)
            }
        default:
            break
        }
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate

extension DataOutputProcessor: AVCaptureDataOutputSynchronizerDelegate {
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        //let dataCount = synchronizedDataCollection.count
        //print("\(dataCount) data outputs received")
        
        if let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData {
            let depthTimestamp = syncedDepthData.timestamp
            //print("depth output received at \(CMTimeGetSeconds(depthTimestamp))")
            if !syncedDepthData.depthDataWasDropped {
                let depthData = syncedDepthData.depthData
                processDepth(depthData: depthData, timestamp: depthTimestamp)
            } else {
                print("depth frame dropped for reason: \(syncedDepthData.droppedReason.rawValue)")
            }
        }
        /*
        if let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData {
            let videoTimestamp = syncedVideoData.timestamp
            //print("video output received at \(CMTimeGetSeconds(videoTimestamp))")
            if !syncedVideoData.sampleBufferWasDropped {
                let videoSampleBuffer = syncedVideoData.sampleBuffer
                //CMSampleBufferCreateCopy
                processVideo(sampleBuffer: videoSampleBuffer, timestamp: videoTimestamp)
            } else {
                print("video frame dropped for reason: \(syncedVideoData.droppedReason.rawValue)")
            }
        }
        */
        if let syncedAudioData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: audioDataOutput) as? AVCaptureSynchronizedSampleBufferData {
            let audioTimestamp = syncedAudioData.timestamp
            //print("audio output received at \(CMTimeGetSeconds(audioTimestamp))")
            if !syncedAudioData.sampleBufferWasDropped {
                let audioSampleBuffer = syncedAudioData.sampleBuffer
                processAudio(sampleBuffer: audioSampleBuffer, timestamp: audioTimestamp)
            } else {
                print("audio frame dropped for reason: \(syncedAudioData.droppedReason.rawValue)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DataOutputProcessor: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoDataOutput{
            let videoTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            processVideo(sampleBuffer: sampleBuffer, timestamp: videoTimestamp)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //let droppedReason = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReason, attachmentModeOut: nil) as? String
        //print("Video frame dropped with reason: \(droppedReason ?? "unknown")")
    }
}

// MARK: - VisionTrackerProcessorDelegate Methods

extension DataOutputProcessor: VisionTrackerProcessorDelegate {
    
    func displayFrame(_ faceObservation: VNFaceObservation, confidence: VNConfidence?, captureQuality: Float?) {
        if cameraViewController?.trackingState != .tracking {
            cameraViewController?.trackingState = .tracking
        }
        cameraViewController?.displayFaceObservations(faceObservation)
        cameraViewController?.displayMetrics(confidence: confidence, captureQuality: captureQuality)
    }
    
    func checkAlignment(of faceObservation: VNFaceObservation) {
        let faceBounds = faceObservation.boundingBox
        //print("x: \(faceBounds.midX)")
        //print("y: \(faceBounds.midY)")
        //print("size: \(faceBounds.size)")
        
        // Check if face is centered on the screen
        let centerPoint = CGPoint(x: 0.5, y: 0.43)
        let centerErrorMargin: CGFloat = 0.1
        let xError = (faceBounds.midX - centerPoint.x).magnitude
        let yError = (faceBounds.midY - centerPoint.y).magnitude
        let centeredCondition = xError <= centerErrorMargin && yError <= centerErrorMargin
        //print("x error: \(xError) y error: \(yError)")
        
        // Check if face is correct size on screen
        let size = CGSize(width: 0.6, height: 0.48)
        let sizeErrorMargin: CGFloat = 0.15
        let widthError = (faceBounds.width - size.width).magnitude
        let heightError = (faceBounds.height - size.height).magnitude
        let sizeCondition = widthError <= sizeErrorMargin && heightError <= sizeErrorMargin
        //print("width error: \(widthError) height error: \(heightError)")
        
        // Get face rotation
        /*if faceObservation.yaw != nil, faceObservation.roll != nil {
            print("rotation found")
        } else {
            print("rotation not found")
        }*/
        // If the roll and/or yaw is not found, it will default to 0.0 so that the rotation condition is true (i.e. it doesn't check the rotation)
        let faceRoll = CGFloat(truncating: faceObservation.roll ?? 0.0)
        let faceYaw = CGFloat(truncating: faceObservation.yaw ?? 0.0)
        //print("roll: \(faceRoll) yaw: \(faceYaw)")
        
        // Check if face is facing screen
        let rotation: CGFloat = 10
        let rotationErrorMargin = radiansForDegrees(rotation)
        let rotationCondition = faceRoll.magnitude <= rotationErrorMargin && faceYaw.magnitude <= rotationErrorMargin
        
        let isAligned: Bool = centeredCondition && sizeCondition && rotationCondition
        
        cameraViewController?.isAligned = isAligned
        
        DispatchQueue.main.async {
            self.cameraViewController?.updateIndicator()
        }
    }
    
    func recordLandmarks(of faceObservation: VNFaceObservation) {
        // Write face observation results to file if collecting data.
        // Perform data collection in background queue so that it does not hold up the UI.
        if self.recordingState == .recording {
            guard let landmarksProcessor = self.faceProcessor,
                  let landmarksFileWriter = self.faceLandmarksFileWriter else {
                print("No face landmarks processor and/or file writer found, failed to write to file.")
                return
            }
            
            let (boundingBox, landmarks) = landmarksProcessor.processFace(faceObservation, with: self.depthData, settings: sessionManager.processorSettings)
            landmarksFileWriter.writeToCSV(boundingBox: boundingBox, landmarks: landmarks)
        }
    }
    
    func didFinishTracking() {
        // Update tracking state
        cameraViewController?.trackingState = .stopped
    }
}
