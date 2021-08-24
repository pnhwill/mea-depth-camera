//
//  CaptureOutputPipeline.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation
import Combine
import Vision

class CaptureOutputPipeline: NSObject, DataPipeline {
    
    // Weak reference to camera view controller (parent)
    private weak var cameraViewController: CameraViewController?
    
    // Preview view
    private weak var previewView: PreviewMetalView?
    
    // Data outputs
    private unowned var videoDataOutput: AVCaptureVideoDataOutput
    private unowned var depthDataOutput: AVCaptureDepthDataOutput
    //private unowned var metadataOutput: AVCaptureMetadataOutput
    private unowned var audioDataOutput: AVCaptureAudioDataOutput
    
    private(set) var processorSettings: ProcessorSettings!
    
    // Synchronized data capture
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    // Data output synchronizer queue
    let dataOutputQueue = DispatchQueue(label: "synchronized data output queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // Recording
    var recordingState = RecordingState.idle
    
    // Depth processing
    let videoDepthConverter = DepthToGrayscaleConverter()
    
    // Real time Vision requests
    private(set) var faceDetectionProcessor: LiveFaceDetectionProcessor?
    
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
    
    // Subjects and subscribers
    typealias FileWriterSubject = PassthroughSubject<WriteState, Error>
    var videoWriterSubject: FileWriterSubject?
    var audioWriterSubject: FileWriterSubject?
    var depthWriterSubject: FileWriterSubject?
    
    var fileWritingDone: AnyCancellable?
    
    // Face landmarks post-processing
    
    private var faceLandmarksPipeline: FaceLandmarksPipeline?
    private let savedRecordingsDataSource = SavedRecordingsDataSource()
    
    let recordingQueue = DispatchQueue(label: "recording queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // Use case
    private let useCase: UseCase
    
    init(cameraViewController: CameraViewController,
         useCase: UseCase,
         videoDataOutput: AVCaptureVideoDataOutput,
         depthDataOutput: AVCaptureDepthDataOutput,
         audioDataOutput: AVCaptureAudioDataOutput) {
        self.cameraViewController = cameraViewController
        self.useCase = useCase
        self.videoDataOutput = videoDataOutput
        self.depthDataOutput = depthDataOutput
        self.audioDataOutput = audioDataOutput
    }
    
    // MARK: - Data Pipeline Setup
    func configureProcessors(for videoDevice: AVCaptureDevice) {
        
        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput, audioDataOutput])
        outputSynchronizer?.setDelegate(self, queue: dataOutputQueue)
        
        let videoFormatDescription = videoDevice.activeFormat.formatDescription
        guard let depthDataFormatDescription = videoDevice.activeDepthDataFormat?.formatDescription else { return }
        let videoDimensions = CMVideoFormatDescriptionGetDimensions(videoFormatDescription)
        let depthDimensions = CMVideoFormatDescriptionGetDimensions(depthDataFormatDescription)
        
        guard let connection = videoDataOutput.connection(with: .video) else { return }
        let videoOrientation = connection.videoOrientation
        
        self.processorSettings = ProcessorSettings(videoDimensions: videoDimensions, depthDimensions: depthDimensions, videoOrientation: videoOrientation)
        
        self.faceDetectionProcessor = LiveFaceDetectionProcessor()
        self.faceDetectionProcessor?.delegate = self
        
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
                                                                 videoFormat: videoFormatDescription)
        
        // Initialize audio file writer configuration
        let audioSettingsForAudio = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: audioFileSettings.fileType)
        audioFileSettings.configuration = AudioFileConfiguration(fileType: audioFileSettings.fileType,
                                                                 audioSettings: audioSettingsForAudio)
        
        // Initialize depth map file writer configuration
        let videoSettingsForDepthMap = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: depthMapFileSettings.fileType)
        depthMapFileSettings.configuration = DepthMapFileConfiguration(fileType: depthMapFileSettings.fileType,
                                                                       videoSettings: videoSettingsForDepthMap,
                                                                       transform: videoTransform)
    }
    
    func configureSavedRecordingsDataSource(container: PersistentContainer) {
        savedRecordingsDataSource.persistentContainer = container
        cameraViewController?.updateRecordingsCount(count: savedRecordingsDataSource.savedRecordings.count)
    }
    
    private func createVideoTransform(for output: AVCaptureOutput) -> CGAffineTransform? {
        guard let connection = output.connection(with: .video) else {
            print("Could not find the camera video connection")
            return nil
        }
        // We set the desired destination video orientation here. The interface orientation is locked in portrait for this version
        guard let destinationVideoOrientation = AVCaptureVideoOrientation(interfaceOrientation: .portrait) else {
            print("Unsupported interface orientation")
            return nil
        }
        
        // Compute transforms from the front camera's video orientation to the desired orientation
        let cameraTransform = connection.videoOrientationTransform(relativeTo: destinationVideoOrientation)

        return cameraTransform
    }
    
    // MARK: - Data Processing Methods
    func processDepth(depthData: AVDepthData, timestamp: CMTime) {
        
        // We need to do additional setup upon receiving the first depth frame
        
        // Set the camera calibration data in the processor settings
        if processorSettings.cameraCalibrationData == nil {
            if let cameraCalibrationData = depthData.cameraCalibrationData {
                processorSettings.cameraCalibrationData = cameraCalibrationData
            } else {
                print("Failed to retrieve camera calibration data")
            }
            // Initialize face landmarks processor once we have the processor settings
            if let cameraViewController = cameraViewController {
                faceLandmarksPipeline = FaceLandmarksPipeline(cameraViewController: cameraViewController, processorSettings: processorSettings, savedRecordingsDataSource: savedRecordingsDataSource)
            } else {
                print("Failed to initialize face landmarks processor: camera view controller not found")
            }
        }
        
        // Ensure depth data is of the correct type
        let depthDataType = kCVPixelFormatType_DepthFloat32
        var convertedDepth: AVDepthData
        if depthData.depthDataType != depthDataType {
            convertedDepth = depthData.converting(toDepthDataType: depthDataType)
        } else {
            convertedDepth = depthData
        }
        
        // Prepare the depth to grayscale converter and depth map file configuration
        if !self.videoDepthConverter.isPrepared {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: convertedDepth.depthDataMap,
                                                         formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                self.videoDepthConverter.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 2)
                
                // Since the depth map frames are converted from DepthFloat32 to 32BGRA pixel format by the converter,
                //  we need to set the source video format and source pixel buffer attributes in our file configuration to match.
                // The output format description is set inside the prepare() method call, so we can safely do this as soon as it returns.
                if var depthMapFileConfiguration = self.depthMapFileSettings.configuration as? DepthMapFileConfiguration,
                   let grayscaleFormat = self.videoDepthConverter.outputFormatDescription {
                    depthMapFileConfiguration.sourceVideoFormat = grayscaleFormat
                    depthMapFileConfiguration.sourcePixelBufferAttributes = DepthToGrayscaleConverter.createOutputPixelBufferAttributes(from: unwrappedDepthFormatDescription)
                    let inputDimensions = CMVideoFormatDescriptionGetDimensions(unwrappedDepthFormatDescription)
                    depthMapFileConfiguration.videoSettings?["AVVideoWidthKey"] = Int(inputDimensions.width)
                    depthMapFileConfiguration.videoSettings?["AVVideoHeightKey"] = Int(inputDimensions.height)
                    self.depthMapFileSettings.configuration = depthMapFileConfiguration
                } else {
                    print("Failed to set depth map source format in file configuration")
                }
            }
        }
        
        if recordingState != .idle {
            recordingQueue.async {
                // Convert the depth map to a video format accepted by the AVAssetWriter, then write to file
                guard let depthPixelBuffer = self.videoDepthConverter.render(pixelBuffer: convertedDepth.depthDataMap) else {
                    print("Unable to process depth")
                    return
                }
                self.writeDepthMapToFile(depthMap: depthPixelBuffer, timeStamp: timestamp)
            }
        }
    }
    
    func processVideo(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        
        if recordingState != .idle {
            recordingQueue.async {
                self.writeOutputToFile(self.videoDataOutput, sampleBuffer: sampleBuffer)
            }
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        sampleBuffer.propagateAttachments(to: pixelBuffer)

        if recordingState == .idle {
            if let visionProcessor = self.faceDetectionProcessor {
                visionProcessor.performVisionRequests(on: pixelBuffer)
            } else {
                print("Vision face detection processor not found.")
            }
        }

        if let cameraViewController = cameraViewController, cameraViewController.renderingEnabled {
            cameraViewController.previewView.pixelBuffer = pixelBuffer
        }
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        
        if recordingState != .idle {
            recordingQueue.async {
                self.writeOutputToFile(self.audioDataOutput, sampleBuffer: sampleBuffer)
            }
        }
    }
    
    // MARK: - Data Recording
    
    func startRecording() {
        self.recordingState = .start
        
        // Initialize passthrough subjects to retrieve status from file writers
        self.videoWriterSubject = FileWriterSubject()
        self.audioWriterSubject = FileWriterSubject()
        self.depthWriterSubject = FileWriterSubject()
        
        recordingQueue.async {
            // Create folder for all data files
            guard let saveFolder = self.createFolder() else {
                print("Failed to create save folder")
                return
            }
            guard let audioURL = self.createFileURL(in: saveFolder, nameLabel: OutputType.audio.rawValue, fileType: self.audioFileSettings.fileExtension) else {
                print("Failed to create audio file")
                return
            }
            guard let videoURL = self.createFileURL(in: saveFolder, nameLabel: OutputType.video.rawValue, fileType: self.videoFileSettings.fileExtension) else {
                print("Failed to create video file")
                return
            }
            guard let depthMapURL = self.createFileURL(in: saveFolder, nameLabel: OutputType.depth.rawValue, fileType: self.depthMapFileSettings.fileExtension) else {
                print("Failed to create depth map file")
                return
            }
            
            guard let videoConfiguration = self.videoFileSettings.configuration,
                  let audioConfiguration = self.audioFileSettings.configuration,
                  let depthMapConfiguration = self.depthMapFileSettings.configuration else {
                print("AV file configurations not found")
                return
            }

            let fileDictionary = [OutputType.audio: audioURL, OutputType.video: videoURL, OutputType.depth: depthMapURL]
            self.savedRecordingsDataSource.addRecording(saveFolder, outputFiles: fileDictionary)
            
            do {
                self.videoFileWriter = try VideoFileWriter(outputURL: videoURL, configuration: videoConfiguration as! VideoFileConfiguration, subject: self.videoWriterSubject!)
            } catch {
                print("Error creating video file writer: \(error)")
            }
            do {
                self.audioFileWriter = try AudioFileWriter(outputURL: audioURL, configuration: audioConfiguration as! AudioFileConfiguration, subject: self.audioWriterSubject!)
            } catch {
                print("Error creating audio file writer: \(error)")
            }
            do {
                self.depthMapFileWriter = try DepthMapFileWriter(outputURL: depthMapURL, configuration: depthMapConfiguration as! DepthMapFileConfiguration, subject: self.depthWriterSubject!)
            } catch {
                print("Error creating depth map file writer: \(error)")
            }

        }
        
        // Set up subscriber do receive file writer statuses
        self.fileWritingDone = self.videoWriterSubject!.combineLatest(self.depthWriterSubject!, self.audioWriterSubject!)
        .sink(receiveCompletion: { [weak self] completion in
            self?.handleRecordingFinish(completion: completion)
        }, receiveValue: { [weak self] state in
            if state == (.active, .active, .active) {
                self?.recordingState = .recording
            }
        })
    }
    
    func stopRecording() {
        videoFileWriter?.endRecording()
        audioFileWriter?.endRecording()
        depthMapFileWriter?.endRecording()
        videoFileWriter = nil
        audioFileWriter = nil
        depthMapFileWriter = nil
        recordingState = .finish
        cameraViewController?.updateRecordingsCount(count: savedRecordingsDataSource.savedRecordings.count)
    }
    
    private func handleRecordingFinish(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            // update ui with success
            print("File writing success")
            DispatchQueue.main.async {
                self.cameraViewController?.processingMode = .track
            }
            break
        case .failure(let error):
            // update ui with failure
            print("File writing failure: \(error.localizedDescription)")
            break
        }
        recordingState = .idle
    }
    
    // MARK: - File Writing
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
    
    private func writeOutputToFile(_ output: AVCaptureOutput, sampleBuffer: CMSampleBuffer) {
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
            if output === videoDataOutput, videoWriter.writeState == .inactive {
                videoWriter.start(at: presentationTime)
            }
            if output === audioDataOutput, audioWriter.writeState == .inactive {
                audioWriter.start(at: presentationTime)
            }
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

extension CaptureOutputPipeline: AVCaptureDataOutputSynchronizerDelegate {
    
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

// MARK: - VisionFaceDetectionProcessorDelegate Methods

extension CaptureOutputPipeline: LiveFaceDetectionProcessorDelegate {
    
    func displayFrame(_ faceObservations: [VNFaceObservation]) {
        cameraViewController?.displayFaceObservations(faceObservations)
        //cameraViewController?.displayMetrics(confidence: confidence)
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
    }
}
