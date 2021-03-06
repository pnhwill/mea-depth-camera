//
//  CapturePipeline.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation
import Combine
import Vision
import OSLog

// MARK: - CapturePipelineDelegate
protocol CapturePipelineDelegate: AnyObject {
    
    func previewPixelBufferReadyForDisplay(_ previewPixelBuffer: CVPixelBuffer)
    
    func audioSampleBufferReadyForDisplay(_ sampleBuffer: CMSampleBuffer)
    
    func setFaceAlignment(_ isAligned: Bool)
    
    func capturePipelineRecordingDidStop()
}

// MARK: - CapturePipeline

/// The `CapturePipeline` class implements the real-time processing pipeline for camera and microphone data received during recording.
///
final class CapturePipeline: NSObject {
    
    typealias FileWriterSubject = PassthroughSubject<WriteState, Error>
    
    enum RecordingState {
        case idle, start, recording, finish
    }
    
    private struct FileWriterSettings {
        let fileType: AVFileType
        var configuration: FileConfiguration?
    }
    
    // Data output synchronizer queue
    let dataOutputQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("captureQueue"),
        qos: .userInitiated,
        autoreleaseFrequency: .workItem)
    
    // Depth processing
    let videoDepthConverter = DepthToGrayscaleConverter()
    
    // Recording
    private(set) var recordingState = RecordingState.idle
    
    private weak var delegate: CapturePipelineDelegate?
    
    // Data outputs
    private unowned var videoDataOutput: AVCaptureVideoDataOutput
    private unowned var depthDataOutput: AVCaptureDepthDataOutput
    private unowned var audioDataOutput: AVCaptureAudioDataOutput
    
    private var processorSettings: ProcessorSettings!
    
    // Synchronized data capture
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    // Real time Vision requests
    private var faceDetectionProcessor: LiveFaceDetectionProcessor?
    
    // AV file writing
    private var videoFileWriter: VideoFileWriter?
    private var audioFileWriter: AudioFileWriter?
    private var depthMapFileWriter: DepthMapFileWriter?
    
    private var videoFileSettings = FileWriterSettings(fileType: .mov)
    private var audioFileSettings = FileWriterSettings(fileType: .wav)
    private var depthMapFileSettings = FileWriterSettings(fileType: .mov)
    
    // Subjects and subscribers
    private var videoWriterSubject: FileWriterSubject?
    private var audioWriterSubject: FileWriterSubject?
    private var depthWriterSubject: FileWriterSubject?
    
    private var fileWritingDone: AnyCancellable?
    
    // Save recordings to persistent storage
    private let captureRecordingDataSource: CaptureRecordingDataSource
    
    private let recordingQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("recordingQueue"),
        qos: .userInitiated,
        autoreleaseFrequency: .workItem)
    
    private let useCase: UseCase
    private let task: Task
    
    private let logger = Logger.Category.capture.logger
    
    // MARK: INIT
    init?(delegate: CapturePipelineDelegate,
          useCase: UseCase,
          task: Task,
          videoDataOutput: AVCaptureVideoDataOutput,
          depthDataOutput: AVCaptureDepthDataOutput,
          audioDataOutput: AVCaptureAudioDataOutput) {
        guard let captureRecordingDataSource = CaptureRecordingDataSource(useCase: useCase) else { return nil }
        self.delegate = delegate
        self.useCase = useCase
        self.task = task
        self.videoDataOutput = videoDataOutput
        self.depthDataOutput = depthDataOutput
        self.audioDataOutput = audioDataOutput
        self.captureRecordingDataSource = captureRecordingDataSource
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
        
        // Initialize video file writer configuration
        let videoSettingsForVideo = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: videoFileSettings.fileType)
        let audioSettingsForVideo = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: videoFileSettings.fileType)
        guard let videoTransform = self.createVideoTransform(for: videoDataOutput) else {
            logger.error("Could not create video transform.")
            return
        }
        videoFileSettings.configuration = VideoFileConfiguration(
            fileType: videoFileSettings.fileType,
            videoSettings: videoSettingsForVideo,
            audioSettings: audioSettingsForVideo,
            transform: videoTransform,
            videoFormat: videoFormatDescription)
        
        // Initialize audio file writer configuration
        let audioSettingsForAudio = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: audioFileSettings.fileType)
        audioFileSettings.configuration = AudioFileConfiguration(
            fileType: audioFileSettings.fileType,
            audioSettings: audioSettingsForAudio)
        
        // Initialize depth map file writer configuration
        let videoSettingsForDepthMap = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: depthMapFileSettings.fileType)
        depthMapFileSettings.configuration = DepthMapFileConfiguration(
            fileType: depthMapFileSettings.fileType,
            videoSettings: videoSettingsForDepthMap,
            transform: videoTransform)
    }
    
    // MARK: - Data Recording
    
    func startRecording() {
        self.recordingState = .start
        
        // Initialize passthrough subjects to retrieve status from file writers
        self.videoWriterSubject = FileWriterSubject()
        self.audioWriterSubject = FileWriterSubject()
        self.depthWriterSubject = FileWriterSubject()
        
        let taskFileName = task.fileNameLabel ?? "UNKNOWN_TASK"
        
        recordingQueue.async {
            // Create folder for all data files
            guard let folderURL = self.captureRecordingDataSource.createRecordingFolder(prefix: taskFileName) else {
                self.logger.error("Failed to create save folder.")
                return
            }
            guard let videoConfiguration = self.videoFileSettings.configuration as? VideoFileConfiguration,
                  let audioConfiguration = self.audioFileSettings.configuration as? AudioFileConfiguration,
                  let depthMapConfiguration = self.depthMapFileSettings.configuration as? DepthMapFileConfiguration
            else {
                self.logger.error("AV file configurations not found.")
                return
            }
            
            do {
                let videoFileWriter = try VideoFileWriter(
                    folderURL: folderURL,
                    configuration: videoConfiguration,
                    subject: self.videoWriterSubject!)
                let audioFileWriter = try AudioFileWriter(
                    folderURL: folderURL,
                    configuration: audioConfiguration,
                    subject: self.audioWriterSubject!)
                let depthMapFileWriter = try DepthMapFileWriter(
                    folderURL: folderURL,
                    configuration: depthMapConfiguration,
                    subject: self.depthWriterSubject!)
                
                let fileDictionary: [OutputType: URL] = [
                    .audio: audioFileWriter.fileURL,
                    .video: videoFileWriter.fileURL,
                    .depth: depthMapFileWriter.fileURL,
                ]
                self.captureRecordingDataSource.addRecording(folderURL, outputFiles: fileDictionary, processorSettings: self.processorSettings)
                
                self.videoFileWriter = videoFileWriter
                self.audioFileWriter = audioFileWriter
                self.depthMapFileWriter = depthMapFileWriter
            } catch {
                self.logger.error("Error creating file writer: \(String(describing: error))")
            }
        }
        
        // Set up subscriber to receive file writer statuses.
        self.fileWritingDone = self.videoWriterSubject!
            .combineLatest(self.depthWriterSubject!, self.audioWriterSubject!)
            .sink(receiveCompletion: { [weak self] completion in
                self?.logger.notice("File writing completed.")
                self?.handleRecordingFinish(completion: completion)
            }, receiveValue: { [weak self] state in
                if state == (.active, .active, .active) {
                    self?.logger.notice("Recording is active. Frames will now be saved to files.")
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
        captureRecordingDataSource.saveRecording(to: useCase, for: task)
    }
}

// MARK: - Private Methods
extension CapturePipeline {
    
    private func createVideoTransform(for output: AVCaptureOutput) -> CGAffineTransform? {
        guard let connection = output.connection(with: .video) else {
            logger.error("Could not find the camera video connection.")
            return nil
        }
        // We set the desired destination video orientation here. The interface orientation is locked in portrait for this version
        guard let destinationVideoOrientation = AVCaptureVideoOrientation(interfaceOrientation: .portrait) else {
            logger.error("Unsupported interface orientation.")
            return nil
        }
        
        // Compute transforms from the front camera's video orientation to the desired orientation
        let cameraTransform = connection.videoOrientationTransform(relativeTo: destinationVideoOrientation)

        return cameraTransform
    }
    
    // MARK: - Data Processing
    private func processDepth(depthData: AVDepthData, timestamp: CMTime) {
        
        // We need to do additional setup upon receiving the first depth frame
        
        // Set the camera calibration data in the processor settings
        if processorSettings.cameraCalibrationData == nil {
            if let cameraCalibrationData = depthData.cameraCalibrationData {
                processorSettings.cameraCalibrationData = cameraCalibrationData
            } else {
                logger.error("Failed to retrieve camera calibration data.")
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
                    logger.error("Failed to set depth map source format in file configuration.")
                }
            }
        }
        
        if recordingState != .idle {
            recordingQueue.async {
                // Convert the depth map to a video format accepted by the AVAssetWriter, then write to file
                guard let depthPixelBuffer = self.videoDepthConverter.render(pixelBuffer: convertedDepth.depthDataMap) else {
                    self.logger.error("Unable to process depth.")
                    return
                }
                self.writeDepthMapToFile(depthMap: depthPixelBuffer, timeStamp: timestamp)
            }
        }
    }
    
    private func processVideo(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        
        if recordingState != .idle {
            recordingQueue.async {
                self.writeOutputToFile(self.videoDataOutput, sampleBuffer: sampleBuffer)
            }
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        sampleBuffer.propagateAttachments(to: pixelBuffer)

        if recordingState == .idle {
            if let visionProcessor = self.faceDetectionProcessor {
                visionProcessor.performVisionRequests(on: pixelBuffer) { faceObservation in
                    let faceAlignment = FaceAlignment(faceObservation: faceObservation)
                    delegate?.setFaceAlignment(faceAlignment.isAligned)
                }
            } else {
                logger.error("Vision face detection processor not found.")
            }
        }
        
        delegate?.previewPixelBufferReadyForDisplay(pixelBuffer)
    }
    
    private func processAudio(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        
        if recordingState != .idle {
            recordingQueue.async {
                self.writeOutputToFile(self.audioDataOutput, sampleBuffer: sampleBuffer)
            }
        }
        
        delegate?.audioSampleBufferReadyForDisplay(sampleBuffer)
    }
    
    private func handleRecordingFinish(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            logger.info("Successfully saved recording to files.")
            delegate?.capturePipelineRecordingDidStop()
            break
        case .failure(let error):
            // TODO: update ui with failure
            logger.error("File writing failure: \(error.localizedDescription)")
            break
        }
        recordingState = .idle
    }
    
    // MARK: - File Writing
//    private func writeOutputToFile<T>(_ output: AVCaptureOutput, data: T) {}
    
    private func writeDepthMapToFile(depthMap: CVPixelBuffer, timeStamp: CMTime) {
        guard let depthMapWriter = depthMapFileWriter else {
            logger.error("No depth map file writer found.")
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
        guard let videoWriter = videoFileWriter, let audioWriter = audioFileWriter else {
            logger.error("No video and/or audio file writer found.")
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

extension CapturePipeline: AVCaptureDataOutputSynchronizerDelegate {
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
//        let dataCount = synchronizedDataCollection.count
//        logger.notice("\(dataCount) data outputs received.")
        
        if let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData {
            let depthTimestamp = syncedDepthData.timestamp
            //print("depth output received at \(CMTimeGetSeconds(depthTimestamp))")
            if !syncedDepthData.depthDataWasDropped {
                let depthData = syncedDepthData.depthData
                processDepth(depthData: depthData, timestamp: depthTimestamp)
            } else {
                logger.notice("Depth frame dropped at \(CMTimeGetSeconds(depthTimestamp), format: .fixed(precision: 3)) for reason: \(syncedDepthData.droppedReason.rawValue)")
            }
        }
        
        if let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData {
            let videoTimestamp = syncedVideoData.timestamp
            //print("video output received at \(CMTimeGetSeconds(videoTimestamp))")
            if !syncedVideoData.sampleBufferWasDropped {
                let videoSampleBuffer = syncedVideoData.sampleBuffer
                processVideo(sampleBuffer: videoSampleBuffer, timestamp: videoTimestamp)
            } else {
                logger.notice("Video frame dropped at \(CMTimeGetSeconds(videoTimestamp), format: .fixed(precision: 3)) for reason: \(syncedVideoData.droppedReason.rawValue)")
            }
        }
        
        if let syncedAudioData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: audioDataOutput) as? AVCaptureSynchronizedSampleBufferData {
            let audioTimestamp = syncedAudioData.timestamp
            //print("audio output received at \(CMTimeGetSeconds(audioTimestamp))")
            if !syncedAudioData.sampleBufferWasDropped {
                let audioSampleBuffer = syncedAudioData.sampleBuffer
                processAudio(sampleBuffer: audioSampleBuffer, timestamp: audioTimestamp)
            } else {
                logger.notice("Audio frame dropped at \(CMTimeGetSeconds(audioTimestamp), format: .fixed(precision: 3)) for reason: \(syncedAudioData.droppedReason.rawValue)")
            }
        }
    }
}
