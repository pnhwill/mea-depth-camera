//
//  CaptureSessionManager.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation
import OSLog

/// Helper class that creates and manages the AVCaptureSession.
class CaptureSessionManager: NSObject {
    
    typealias SessionSetupCompletedAction = (AVCaptureDevice, AVCaptureVideoDataOutput, AVCaptureDepthDataOutput, AVCaptureAudioDataOutput) -> Void
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    var setupResult: SessionSetupResult = .success
    
    // AVCapture session
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    private(set) var session = AVCaptureSession()
    private(set) var videoDevice: AVCaptureDevice!
    
    // Data outputs
    private(set) var videoDataOutput = AVCaptureVideoDataOutput()
    private(set) var depthDataOutput = AVCaptureDepthDataOutput()
    private(set) var audioDataOutput = AVCaptureAudioDataOutput()
    //private(set) var metadataOutput = AVCaptureMetadataOutput()
    
    // Video output resolution and orientation for processor settings
//    private var videoDimensions: CMVideoDimensions?
//    private var depthDimensions: CMVideoDimensions?
//    private var videoOrientation: AVCaptureVideoOrientation?
    
    // Configuration options
    private let discardLateFrames: Bool = false
    private let depthDataFiltering: Bool = false
    
    private let logger = Logger.Category.camera.logger
    
    // MARK: - Session Configuration
    
    func configureSession(completion: SessionSetupCompletedAction) {
        if setupResult != .success {
            return
        }
        logger.info("Start configuring AVCaptureSession...")
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
        do {
            // Configure inputs
            try configureFrontCamera()
            try configureMicrophone()
            // Configure outputs
            try configureVideoDataOutput()
            try configureDepthDataOutput()
            try configureAudioDataOutput()
            // Configure device format
            try configureDeviceFormat()
        } catch {
            setupResult = .configurationFailed
            logger.error("Failed to configure AVCaptureSession with code \(String(describing: error)): \(error.localizedDescription)")
            return
        }
        
        logger.info("Finished configuring AVCaptureSession.")
        completion(videoDevice, videoDataOutput, depthDataOutput, audioDataOutput)
    }
    
    // MARK: - Capture Devices
    
    private func configureFrontCamera() throws {
        // Configure front TrueDepth camera as an AVCaptureDevice
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            throw SessionSetupError.noVideoDevice
        }
        videoDevice = captureDevice
        
        // Ensure we can create a valid device input
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            throw SessionSetupError.videoInputInitializationFailed(error)
        }
        
        // Add a video input
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
        } else {
            throw SessionSetupError.cannotAddVideoInput
        }
        logger.info("Successfully added video device input.")
    }
    
    private func configureMicrophone() throws {
        // Add an audio input device.
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw SessionSetupError.noAudioDevice
        }
        do {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                throw SessionSetupError.cannotAddAudioInput
            }
        } catch {
            throw SessionSetupError.audioInputInitializationFailed(error)
        }
        logger.info("Successfully added audio device input.")
    }
    
    // MARK: - Data Outputs
    
    private func configureVideoDataOutput() throws {
        // Add a video data output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            if let connection = videoDataOutput.connection(with: .video) {
                connection.isEnabled = true
                if connection.isCameraIntrinsicMatrixDeliverySupported {
                    connection.isCameraIntrinsicMatrixDeliveryEnabled = true
                } else {
                    throw SessionSetupError.noIntrinsicMatrixDelivery
                }
            } else {
                throw SessionSetupError.noVideoCaptureConnection
            }
        } else {
            throw SessionSetupError.cannotAddVideoDataOutput
        }
        videoDataOutput.alwaysDiscardsLateVideoFrames = discardLateFrames
        logger.info("Successfully added video data output.")
    }
    
    private func configureDepthDataOutput() throws {
        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = depthDataFiltering
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
            } else {
                throw SessionSetupError.noDepthCaptureConnection
            }
        } else {
            throw SessionSetupError.cannotAddDepthDataOutput
        }
        depthDataOutput.alwaysDiscardsLateDepthData = discardLateFrames
        logger.info("Successfully added depth data output.")
    }
    
    private func configureAudioDataOutput() throws {
        // Add an audio data output
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
            if let connection = audioDataOutput.connection(with: .audio) {
                connection.isEnabled = true
            } else {
                throw SessionSetupError.noAudioCaptureConnection
            }
        } else {
            throw SessionSetupError.cannotAddAudioDataOutput
        }
        logger.info("Successfully added audio data output.")
    }
    
    // MARK: - Video Format
    
    private func configureDeviceFormat() throws {
        // Search for best video format that supports depth (prioritize highest framerate, then choose highest resolution)
        if let (deviceFormat, frameRateRange, resolution) = bestDeviceFormat(for: videoDevice) {
            do {
                try videoDevice.lockForConfiguration()
                
                // Set the device's active format.
                videoDevice.activeFormat = deviceFormat
                
                // Set the device's min/max frame duration.
                let duration = frameRateRange.minFrameDuration
                videoDevice.activeVideoMinFrameDuration = duration
                videoDevice.activeVideoMaxFrameDuration = duration
                
                // Set device to monitor subject area change so we can re-focus
                videoDevice.isSubjectAreaChangeMonitoringEnabled = true
                
                videoDevice.unlockForConfiguration()
            } catch {
                throw SessionSetupError.videoDeviceConfigurationFailed(error)
            }
            logger.info("Color video framerate: \(frameRateRange.maxFrameRate, format: .fixed(precision: 1)) Hz.")
            logger.info("Color video dimensions: \(resolution).")
//            videoDimensions = resolution
        } else {
            throw SessionSetupError.noValidVideoFormat
        }
        
        // Search for depth data formats with floating-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        
        let depth32formats = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        })
        if depth32formats.isEmpty {
            throw SessionSetupError.noValidDepthFormat
        }
        
        // Select format with highest resolution
        let selectedFormat = depth32formats.max(by: { first, second in
            CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width })
        
        if let selectedFormatDescription = selectedFormat?.formatDescription {
            let depthDimensions = CMVideoFormatDescriptionGetDimensions(selectedFormatDescription)
            logger.info("Depth video dimensions: \(depthDimensions).")
        } else {
            logger.info("Failed to obtain depth data format.")
        }
        
        // Set the depth data format
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch {
            throw SessionSetupError.videoDeviceConfigurationFailed(error)
        }
        logger.info("Successfully configured video device format.")
    }
    
    private func bestDeviceFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, frameRateRange: AVFrameRateRange, resolution: CMVideoDimensions)? {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        // Search only formats that support depth data
        let supportsDepthFormats = device.formats.filter({
            !$0.supportedDepthDataFormats.isEmpty
        })
//        supportsDepthFormats.forEach { debugPrint($0) }
        
        // Search for highest possible framerate
        for format in supportsDepthFormats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFrameRateRange = range
                }
            }
        }
        
        // Search for highest resolution with best framerate
        for format in supportsDepthFormats {
            if format.videoSupportedFrameRateRanges.contains(bestFrameRateRange!) {
                let formatDescription = format.formatDescription
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                // Search full color range pixel formats
                if CMFormatDescriptionGetMediaSubType(formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
//                    debugPrint(formatDescription)
                    if (bestFormat == nil) ||
                       (candidateDimensions.width > highestResolutionDimensions.width) ||
                       ((candidateDimensions.width == highestResolutionDimensions.width) && (candidateDimensions.height > highestResolutionDimensions.height)) {
                        bestFormat = format
                        highestResolutionDimensions = candidateDimensions
                    }
                }
            }
        }
        
        if let bestFormat = bestFormat, let bestFrameRateRange = bestFrameRateRange {
//            [bestFormat, bestFrameRateRange, highestResolutionDimensions].forEach { debugPrint($0) }
            return (bestFormat, bestFrameRateRange, highestResolutionDimensions)
        } else {
            return nil
        }
    }
}

/*
 if self.session.canAddOutput(metadataOutput) {
 self.session.addOutput(metadataOutput)
 if metadataOutput.availableMetadataObjectTypes.contains(.face) {
 metadataOutput.metadataObjectTypes = [.face]
 }
 } else {
 print("Could not add face detection output to the session")
 cameraViewController.setupResult = .configurationFailed
 session.commitConfiguration()
 return
 }
 */


