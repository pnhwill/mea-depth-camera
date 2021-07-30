//
//  CaptureSessionManager.swift
//  MEADepthCamera
//
//  Created by Will on 7/29/21.
//

import AVFoundation

class CaptureSessionManager: NSObject, ObservableObject { // check if observable object is needed?
    
    // Weak reference to owner
    private weak var cameraViewController: CameraViewController!
    
    // Data output processor
    private(set) var dataOutputProcessor: DataOutputProcessor?
    
    // AVCapture session
    private(set) var session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice!
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    // Data output
    private(set) var videoDataOutput = AVCaptureVideoDataOutput()
    private(set) var depthDataOutput = AVCaptureDepthDataOutput()
    //private(set) var metadataOutput = AVCaptureMetadataOutput()
    private(set) var audioDataOutput = AVCaptureAudioDataOutput()
    
    // Synchronized data capture
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    private(set) var videoResolution: CGSize = CGSize()
    private(set) var depthResolution: CGSize = CGSize()
    
    init(cameraViewController: CameraViewController) {
        self.cameraViewController = cameraViewController
    }
    
    // MARK: - Session Configuration
    
    func configureSession() {
        if cameraViewController.setupResult != .success {
            return
        }
        
        // Configure front TrueDepth camera as an AVCaptureDevice
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Could not find any video device")
            cameraViewController.setupResult = .configurationFailed
            return
        }
        
        videoDevice = captureDevice
        
        // Ensure we can create a valid device input
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            cameraViewController.setupResult = .configurationFailed
            return
        }
        
        self.dataOutputProcessor = DataOutputProcessor(sessionManager: self, cameraViewController: cameraViewController)
        
        session.beginConfiguration()
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // Set video data output sample buffer delegate
        videoDataOutput.setSampleBufferDelegate(dataOutputProcessor, queue: cameraViewController.videoOutputQueue)
        
        // Add a video data output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            if let connection = videoDataOutput.connection(with: .video) {
                connection.isEnabled = true
                /*
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                } else {
                    print("Changing video orientation not supported")
                }
                */
                if connection.isCameraIntrinsicMatrixDeliverySupported {
                    connection.isCameraIntrinsicMatrixDeliveryEnabled = true
                } else {
                    print("Camera intrinsic matrix delivery not supported")
                }
            } else {
                print("No AVCaptureConnection for video data output")
            }
        } else {
            print("Could not add video data output to the session")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)
            depthDataOutput.isFilteringEnabled = false
            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
                /*
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                } else {
                    print("Changing depth orientation not supported")
                }
                */
            } else {
                print("No AVCaptureConnection")
            }
        } else {
            print("Could not add depth data output to the session")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Use independent dispatch queue from the video data since the depth processing is much more intensive
        //depthDataOutput.setDelegate(self, callbackQueue: depthOutputQueue)
        
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
                
                videoDevice.unlockForConfiguration()
            } catch {
                print("Failed to set video device format")
                cameraViewController.setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            self.videoResolution = resolution
        } else {
            print("Failed to find valid device format")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Search for highest resolution with floating-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        
        let depth32formats = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        })
        if depth32formats.isEmpty {
            print("Device does not support Float32 depth format")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        let selectedFormat = depth32formats.max(by: { first, second in
                                                    CMVideoFormatDescriptionGetDimensions(first.formatDescription).width <
                                                        CMVideoFormatDescriptionGetDimensions(second.formatDescription).width })
        
        
        if let selectedFormatDescription = selectedFormat?.formatDescription {
            let depthDimensions = CMVideoFormatDescriptionGetDimensions(selectedFormatDescription)
            depthResolution = CGSize(width: CGFloat(depthDimensions.width), height: CGFloat(depthDimensions.height))
        } else {
            print("Failed to obtain depth data resolution")
        }
        
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
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
        // Add an audio input device.
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
            }
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
        // Set audio data output sample buffer delegate
        //audioDataOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        
        // Add an audio data output
        if session.canAddOutput(audioDataOutput) {
            session.addOutput(audioDataOutput)
            if let connection = audioDataOutput.connection(with: .audio) {
                connection.isEnabled = true
            } else {
                print("No AVCaptureConnection for audio data output")
            }
        } else {
            print("Could not add audio data output to the session")
            cameraViewController.setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [depthDataOutput, audioDataOutput])
        outputSynchronizer!.setDelegate(dataOutputProcessor, queue: cameraViewController.dataOutputQueue)
        
        session.commitConfiguration()
        
        dataOutputProcessor?.videoResolution = videoResolution
        dataOutputProcessor?.depthResolution = depthResolution
    }
    
    // MARK: - Device Configuration
    
    private func bestDeviceFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, frameRateRange: AVFrameRateRange, resolution: CGSize)? {
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
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (bestFormat!, bestFrameRateRange!, resolution)
        }
        return nil
    }
    
    
    
}
