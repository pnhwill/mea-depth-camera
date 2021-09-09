//
//  CaptureSessionManager.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation

class CaptureSessionManager: NSObject {
    typealias SessionSetupCompletedAction = (AVCaptureDevice, AVCaptureVideoDataOutput, AVCaptureDepthDataOutput, AVCaptureAudioDataOutput) -> Void
    
    // Weak reference to parent
    private weak var cameraViewController: CameraViewController!
    
    // AVCapture session
    private(set) var session = AVCaptureSession()
    private(set) var videoDevice: AVCaptureDevice!
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    // Data outputs
    private(set) var videoDataOutput = AVCaptureVideoDataOutput()
    private(set) var depthDataOutput = AVCaptureDepthDataOutput()
    //private(set) var metadataOutput = AVCaptureMetadataOutput()
    private(set) var audioDataOutput = AVCaptureAudioDataOutput()
    
    // Video output resolution and orientation for processor settings
    private var videoDimensions: CMVideoDimensions?
    private var depthDimensions: CMVideoDimensions?
    private var videoOrientation: AVCaptureVideoOrientation?
    
    let discardLateFrames: Bool = false
    let depthDataFiltering: Bool = false
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    var setupResult: SessionSetupResult = .success
    
    init(cameraViewController: CameraViewController) {
        self.cameraViewController = cameraViewController
    }
    
    // MARK: - Session Configuration
    
    func configureSession(completion: SessionSetupCompletedAction) {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        // Configure inputs
        guard configureFrontCamera() else {
            setupResult = .configurationFailed
            return
        }
        guard configureMicrophone() else {
            setupResult = .configurationFailed
            return
        }
        // Configure outputs
        guard configureVideoDataOutput() else {
            setupResult = .configurationFailed
            return
        }
        guard configureDepthDataOutput() else {
            setupResult = .configurationFailed
            return
        }
        guard configureAudioDataOutput() else {
            setupResult = .configurationFailed
            return
        }
        // Configure device format
        guard configureDeviceFormat() else {
            setupResult = .configurationFailed
            return
        }

        completion(videoDevice, videoDataOutput, depthDataOutput, audioDataOutput)
    }
    
    // MARK: - Capture Device Configuration
    
    private func configureFrontCamera() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        // Configure front TrueDepth camera as an AVCaptureDevice
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Could not find any video device")
            return false
        }
        videoDevice = captureDevice
        
        // Ensure we can create a valid device input
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            return false
        }
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            return false
        }
        session.addInput(videoDeviceInput)
        
        return true
    }
    
    private func configureMicrophone() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        // Add an audio input device.
        do {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                print("Could not find the microphone")
                return false
            }
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
                return false
            }
        } catch {
            print("Could not create audio device input: \(error)")
            return false
        }
        return true
    }
    
    // MARK: - Data Output Configuration
    
    private func configureVideoDataOutput() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        // Add a video data output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            if let connection = videoDataOutput.connection(with: .video) {
                connection.isEnabled = true
                if connection.isCameraIntrinsicMatrixDeliverySupported {
                    connection.isCameraIntrinsicMatrixDeliveryEnabled = true
                } else {
                    print("Camera intrinsic matrix delivery not supported")
                    return false
                }
            } else {
                print("No AVCaptureConnection for video data output")
                return false
            }
        } else {
            print("Could not add video data output to the session")
            return false
        }
        videoDataOutput.alwaysDiscardsLateVideoFrames = discardLateFrames
        return true
    }
    
    private func configureDepthDataOutput() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = depthDataFiltering
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
            } else {
                print("No AVCaptureConnection for depth data output")
                return false
            }
        } else {
            print("Could not add depth data output to the session")
            return false
        }
        depthDataOutput.alwaysDiscardsLateDepthData = discardLateFrames
        return true
    }
    
    private func configureAudioDataOutput() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        // Add an audio data output
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
            if let connection = audioDataOutput.connection(with: .audio) {
                connection.isEnabled = true
            } else {
                print("No AVCaptureConnection for audio data output")
                return false
            }
        } else {
            print("Could not add audio data output to the session")
            return false
        }
        return true
    }
    
    // MARK: - Device Format Configuration
    
    private func configureDeviceFormat() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
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
                print("Failed to set video device format")
                return false
            }
            videoDimensions = resolution
        } else {
            print("Failed to find valid device format")
            return false
        }
        
        // Search for depth data formats with floating-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        
        let depth32formats = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        })
        if depth32formats.isEmpty {
            print("Device does not support Float32 depth format")
            return false
        }
        
        // Select format with highest resolution
        let selectedFormat = depth32formats.max(by: { first, second in
                                                    CMVideoFormatDescriptionGetDimensions(first.formatDescription).width <
                                                        CMVideoFormatDescriptionGetDimensions(second.formatDescription).width })
        
        if let selectedFormatDescription = selectedFormat?.formatDescription {
            depthDimensions = CMVideoFormatDescriptionGetDimensions(selectedFormatDescription)
            
        } else {
            print("Failed to obtain depth data resolution")
        }
        
        // Set the depth data format
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            return false
        }

        return true
    }
    
    private func bestDeviceFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, frameRateRange: AVFrameRateRange, resolution: CMVideoDimensions)? {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        // Search only formats that support depth data
        let supportsDepthFormats = device.formats.filter({
            !$0.supportedDepthDataFormats.isEmpty
        })
        
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
                    if (bestFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                        bestFormat = format
                        highestResolutionDimensions = candidateDimensions
                    }
                }
            }
        }
        
        if bestFormat != nil {
            //let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (bestFormat!, bestFrameRateRange!, highestResolutionDimensions)
        }
        return nil
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