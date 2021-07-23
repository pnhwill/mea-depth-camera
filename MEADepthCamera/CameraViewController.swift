//
//  ViewController.swift
//  MEADepthCamera
//
//  Created by Will on 7/13/21.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCaptureDepthDataOutputDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    // MARK: - Properties
    
    // Video preview view
    @IBOutlet private weak var previewView: PreviewView!
    
    // UI buttons/labels
    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    @IBOutlet private weak var resumeButton: UIButton!
    @IBOutlet private weak var recordButton: UIButton!
    
    @IBOutlet private weak var qualityLabel: UILabel!
    @IBOutlet private weak var confidenceLabel: UILabel!
    
    @IBOutlet private weak var indicatorImage: UIImageView!
    
    // AVCapture session
    private var session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice!
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    private var setupResult: SessionSetupResult = .success
    private var isSessionRunning = false
    
    // Data output
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var depthDataOutput = AVCaptureDepthDataOutput()
    private var metadataOutput = AVCaptureMetadataOutput()
    private var audioDataOutput = AVCaptureAudioDataOutput()
    
    // Movie recording
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    private enum RecordingState {
        case idle, start, recording, finish
    }
    private var recordingState = RecordingState.idle
    
    private enum WriteState {
        case inactive, active
    }
    private var videoWriteState = WriteState.inactive
    private var audioWriteState = WriteState.inactive
    private var depthMapWriteState = WriteState.inactive
    
    private var videoFileConfiguration: VideoFileConfiguration?
    private var videoFileWriter: VideoFileWriter?
    private var videoFileType: AVFileType = .mov
    private var videoFileExtension: String = "mov"
    
    // Audio recording (to separate audio file)
    private var audioFileConfiguration: AudioFileConfiguration?
    private var audioFileWriter: AudioFileWriter?
    private var audioFileType: AVFileType = .wav
    private var audioFileExtension: String = "wav"
    
    // Depth processing
    var depthData: AVDepthData?
    
    private let videoDepthConverter = DepthToGrayscaleConverter()
    private var renderingEnabled = true
    private var currentDepthPixelBuffer: CVPixelBuffer?
    
    // Depth map recording (to video file)
    private var depthMapFileConfiguration: DepthMapFileConfiguration?
    private var depthMapFileWriter: DepthMapFileWriter?
    private var depthMapFileType: AVFileType = .mov
    private var depthMapFileExtension: String = "mov"
    
    // Data collection
    private var videoResolution: CGSize = CGSize()
    private var depthResolution: CGSize = CGSize()
    
    var faceLandmarksFileWriter: FaceLandmarksFileWriter?
    
    // Vision requests
    var detectionRequests: [VNDetectFaceRectanglesRequest]?
    var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // Layer UI for drawing Vision results
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var observationsOverlay = UIView() // Not necessary, can remove and change references to previewView
    
    var reusableFaceObservationOverlayViews: [FaceObservationOverlayView] {
        if let existingViews = observationsOverlay.subviews as? [FaceObservationOverlayView] {
            return existingViews
        } else {
            return [FaceObservationOverlayView]()
        }
    }
    
    // Vision face analysis
    var faceCaptureQuality: Float?
    var faceLandmarksConfidence: VNConfidence?
    
    // Face guidelines alignment
    private var isAligned: Bool = false
    
    // Dispatch queues
    private var sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    private var videoOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var audioOutputQueue = DispatchQueue(label: "audio data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var depthOutputQueue = DispatchQueue(label: "depth data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // KVO
    private var keyValueObservations = [NSKeyValueObservation]()
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the UI. Enable the UI later, if and only if the session starts running.
        recordButton.isEnabled = false
        
        // Set up the video preview view.
        previewView.session = session
        
        /*
         Check the video authorization status. Video access is required and audio
         access is optional. If the user denies audio access, the app won't
         record audio during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant video access
             We suspend the session queue to delay session setup until the access request has completed
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
            return
        }
        /*
         Set up the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let initialThermalState = ProcessInfo.processInfo.thermalState
        if initialThermalState == .serious || initialThermalState == .critical {
            showThermalState(state: initialThermalState)
        }
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded
                DispatchQueue.main.async {
                    self.designatePreviewLayer()
                    self.prepareVisionRequest()
                }
                self.addObservers()
                
                self.depthOutputQueue.async {
                    self.renderingEnabled = true
                }
                
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("MEADepthCamera doesn't have permission to use the camera, please change privacy settings",
                                                    comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "MEADepthCamera", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                                                            }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "MEADepthCamera", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.depthOutputQueue.async {
            self.renderingEnabled = false
        }
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        super.viewWillDisappear(animated)
    }
    /*
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    */
    // Add didEnterBackground(notification: NSNotification) as in AVCamFilter and an observer
    
    // You can use this opportunity to take corrective action to help cool the system down.
    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }
    
    func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            var thermalStateString = "UNKNOWN"
            if state == .nominal {
                thermalStateString = "NOMINAL"
            } else if state == .fair {
                thermalStateString = "FAIR"
            } else if state == .serious {
                thermalStateString = "SERIOUS"
            } else if state == .critical {
                thermalStateString = "CRITICAL"
            }
            
            let message = NSLocalizedString("Thermal state: \(thermalStateString)", comment: "Alert message when thermal state has changed")
            let alertController = UIAlertController(title: "MEADepthCamera", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: - KVO and Notifications
    
    private func addObservers() {
        
        let sessionRunningObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            
            DispatchQueue.main.async {
                self.recordButton.isEnabled = isSessionRunning// && self.movieFileOutput != nil
            }
        }
        keyValueObservations.append(sessionRunningObservation)
        
        let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: NSNotification.Name.AVCaptureSessionRuntimeError,
                                               object: session)
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: NSNotification.Name.AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    // MARK: - Session Management
    
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        // Configure front TrueDepth camera as an AVCaptureDevice
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Could not find any video device")
            setupResult = .configurationFailed
            return
        }
        
        videoDevice = captureDevice
        
        // Ensure we can create a valid device input
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }
        
        session.beginConfiguration()
        
        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        // Set video data output sample buffer delegate
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
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
            setupResult = .configurationFailed
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
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Use independent dispatch queue from the video data since the depth processing is much more intensive
        depthDataOutput.setDelegate(self, callbackQueue: depthOutputQueue)
        
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
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            self.videoResolution = resolution
        } else {
            print("Failed to find valid device format")
            setupResult = .configurationFailed
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
            setupResult = .configurationFailed
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
            setupResult = .configurationFailed
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
         setupResult = .configurationFailed
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
        audioDataOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        
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
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Initialize video file writer configuration
        // Move this to viewWillAppear() probably
        let videoType = videoFileType
        let videoSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: videoType)
        let audioSettings = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: videoType)
        videoFileConfiguration = VideoFileConfiguration(fileType: videoType, videoSettings: videoSettings, audioSettings: audioSettings)
        
        // Initialize audio file writer configuration
        let audioType = audioFileType
        let audioSettingsForAudioFile = audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: audioType)
        audioFileConfiguration = AudioFileConfiguration(fileType: audioType, audioSettings: audioSettingsForAudioFile)
        
        // Initialize depth map file writer configuration
        let depthMapType = depthMapFileType
        let depthMapSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: depthMapType)
        depthMapFileConfiguration = DepthMapFileConfiguration(fileType: depthMapType, videoSettings: depthMapSettings)
        
        // Initialize landmarks file writer
        // Move to viewWillAppear() probably also
        faceLandmarksFileWriter = FaceLandmarksFileWriter(resolution: videoResolution)
        
        session.commitConfiguration()
    }
    
    @IBAction private func resumeInterruptedSession(_ sender: UIButton) {
        sessionQueue.async {
            /*
             The session might fail to start running, for example, if a phone or FaceTime call is still
             using audio or video. This failure is communicated by the session posting a
             runtime error notification. To avoid repeatedly failing to start the session,
             only try to restart the session in the error handler if you aren't
             trying to resume the session.
             */
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "MEADepthCamera", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    self.resumeButton.isHidden = true
                }
            }
        }
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    @objc
    func sessionWasInterrupted(notification: NSNotification) {
        /*
         In some scenarios you want to enable the user to resume the session.
         For example, if music playback is initiated from Control Center while
         using the app, then the user can let the app resume
         the session running, which will stop music playback. Note that stopping
         music playback in Control Center will not automatically resume the session.
         Also note that it's not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reasonIntegerValue = userInfoValue.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
                // Fade-in a button to enable the user to try to resume the session running.
                resumeButton.alpha = 0
                resumeButton.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.resumeButton.alpha = 1
                }
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Fade-in a label to inform the user that the camera is unavailable.
                cameraUnavailableLabel.alpha = 0
                cameraUnavailableLabel.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.cameraUnavailableLabel.alpha = 1
                }
            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped running due to shutdown system pressure level.")
            }
        }
    }
    
    @objc
    func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
        if !resumeButton.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                            self.resumeButton.alpha = 0
                           }, completion: { _ in
                            self.resumeButton.isHidden = true
                           }
            )
        }
        if !cameraUnavailableLabel.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                            self.cameraUnavailableLabel.alpha = 0
                           }, completion: { _ in
                            self.cameraUnavailableLabel.isHidden = true
                           }
            )
        }
    }
    
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        
        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")
        
        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        self.resumeButton.isHidden = false
                    }
                }
            }
        } else {
            resumeButton.isHidden = false
        }
    }
    
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        let pressureLevel = systemPressureState.level
        /*
         if pressureLevel == .serious || pressureLevel == .critical {
         if self.movieFileOutput == nil || self.movieFileOutput?.isRecording == false {
         do {
         try self.videoDeviceInput.device.lockForConfiguration()
         print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
         self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
         self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
         self.videoDeviceInput.device.unlockForConfiguration()
         } catch {
         print("Could not lock device for configuration: \(error)")
         }
         }
         } else if pressureLevel == .shutdown {
         print("Session stopped running due to shutdown system pressure level.")
         }
         */
        print("System pressure state is now \(pressureLevel.rawValue)")
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
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    // MARK: - Depth Data Output Delegate
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
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
        
        convertedDepth.applyingExifOrientation(exifOrientationForCurrentDeviceOrientation())
        
        //print(convertedDepth.depthDataQuality.rawValue)
        
        guard let depthDataMap = processDepth(depthData: convertedDepth) else {
            print("Failed to get depth map")
            return
        }
        
        if recordingState != .idle {
            writeDepthMapToFile(depthMap: depthDataMap, timeStamp: timestamp)
        }
        
    }

    func processDepth(depthData: AVDepthData) -> CVPixelBuffer? {
        if !renderingEnabled {
            return nil
        }
        
        if !videoDepthConverter.isPrepared {
            var depthFormatDescription: CMFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: depthData.depthDataMap,
                                                         formatDescriptionOut: &depthFormatDescription)
            if let unwrappedDepthFormatDescription = depthFormatDescription {
                videoDepthConverter.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 2)
            }
        }
        
        guard let depthPixelBuffer = videoDepthConverter.render(pixelBuffer: depthData.depthDataMap) else {
            print("Unable to process depth")
            return nil
        }
        
        //currentDepthPixelBuffer = depthPixelBuffer
        
        return depthPixelBuffer
    }
    
    // MARK: - Recording Video, Audio, Depth Map, and Landmarks
    
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
        
        // Create new file in the desired folder
        /*guard FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil) else {
            print("Error creating \(fileName).\(fileType) in documents folder")
            return nil
        }*/
        
        return fileURL
    }
    
    @IBAction private func toggleRecording(_ sender: UIButton) {
        // Don't let the user spam the button
        // Disable the Record button until recording starts or finishes.
        recordButton.isEnabled = false
        
        switch recordingState {
        case .idle:
            // Only let recording start if the face is aligned
            guard isAligned else {
                recordButton.isEnabled = true
                print("Face is not aligned")
                return
            }
            // Create folder for all data files
            guard let saveFolder = createFolder() else {
                print("Failed to create save folder")
                return
            }
            guard let audioURL = createFileURL(in: saveFolder, nameLabel: "audio", fileType: audioFileExtension) else {
                print("Failed to create audio file")
                return
            }
            guard let videoURL = createFileURL(in: saveFolder, nameLabel: "video", fileType: videoFileExtension) else {
                print("Failed to create video file")
                return
            }
            guard let depthMapURL = createFileURL(in: saveFolder, nameLabel: "depth", fileType: depthMapFileExtension) else {
                print("Failed to create depth map file")
                return
            }
            guard let landmarksURL = createFileURL(in: saveFolder, nameLabel: "landmarks", fileType: "csv") else {
                print("Failed to create landmarks file")
                return
            }
            // Ideally this should be done on a background thread I'm not yet sure how to handle the error in an async context
            if UIDevice.current.isMultitaskingSupported {
                self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            }
            do {
                videoFileWriter = try VideoFileWriter(outputURL: videoURL, configuration: videoFileConfiguration!)
            } catch {
                print("Error creating video file writer: \(error)")
            }
            do {
                audioFileWriter = try AudioFileWriter(outputURL: audioURL, configuration: audioFileConfiguration!)
            } catch {
                print("Error creating audio file writer: \(error)")
            }
            do {
                depthMapFileWriter = try DepthMapFileWriter(outputURL: depthMapURL, configuration: depthMapFileConfiguration!)
            } catch {
                print("Error creating depth map file writer: \(error)")
            }
            guard (faceLandmarksFileWriter?.startDataCollection(path: landmarksURL)) != nil else {
                print("No face landmarks file writer found, failed to access startDataCollection().")
                return
            }
            recordingState = .start
        case .recording:
            recordingState = .finish
        default:
            break
        }
    }
    
    //Setting up Asset Writer to save videos

    private func writeDepthMapToFile(depthMap: CVPixelBuffer, timeStamp: CMTime) {
        guard let depthMapWriter = depthMapFileWriter else {
            print("No depth map file writer found")
            return
        }
        
        switch recordingState {
        case .start:
            // If all file writers are already active, change the recording state and fall through to record the frame
            if depthMapWriteState == .active && videoWriteState == .active && audioWriteState == .active {
                recordingState = .recording
                fallthrough
            }
            // If this file writer is inactive, start it and change it's state to active
            if depthMapWriteState == .inactive {
                depthMapWriteState = .active
                depthMapWriter.start(at: timeStamp)
            }
            // Enable the Record button to let the user stop recording.
            DispatchQueue.main.async {
                if !self.recordButton.isEnabled {
                    self.recordButton.isEnabled = true
                    self.recordButton.setBackgroundImage(UIImage(systemName: "stop.circle"), for: [])
                }
            }
            //fallthrough
        case .recording:
            depthMapWriter.writeVideo(depthMap, timeStamp: timeStamp)
        case .finish:
            // If this file writer is active, finish writing and change it's state to inactive when the finish operation completes
            if depthMapWriteState == .active {
                depthMapWriter.finish(at: timeStamp, { result in
                    switch result {
                    case .success:
                        print("depth map file success")
                        // we can add code to export or save the depth map video file to Photos library here
                    case .failed(let error):
                        print("depth map file failure: \(error!.localizedDescription)")
                    }
                    self.depthMapWriteState = .inactive
                })
            }
            // If all file writers are already inactive, change recording state to idle and end the background task
            if depthMapWriteState == .inactive && videoWriteState == .inactive && audioWriteState == .inactive {
                recordingState = .idle
                if let currentBackgroundRecordingID = self.backgroundRecordingID {
                    self.backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                    
                    if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                        UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                    }
                }
            }
            // Enable the Record button to let the user start another recording.
            DispatchQueue.main.async {
                if !self.recordButton.isEnabled {
                    self.recordButton.isEnabled = true
                    self.recordButton.setBackgroundImage(UIImage(systemName: "record.circle.fill"), for: [])
                }
            }
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
            // If all file writers are already active, change the recording state and fall through to record the frame
            if depthMapWriteState == .active && videoWriteState == .active && audioWriteState == .active {
                recordingState = .recording
                fallthrough
            }
            // If these file writers are inactive, start them and change their state to active
            if videoWriteState == .inactive {
                videoWriteState = .active
                videoWriter.start(at: presentationTime)
            }
            if audioWriteState == .inactive {
                audioWriteState = .active
                audioWriter.start(at: presentationTime)
            }
            // Enable the Record button to let the user stop recording.
            DispatchQueue.main.async {
                if !self.recordButton.isEnabled {
                    self.recordButton.isEnabled = true
                    self.recordButton.setBackgroundImage(UIImage(systemName: "stop.circle"), for: [])
                }
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
        case .finish:
            // If these file writers are active, finish writing and change their state to inactive when the finish operation completes
            if videoWriteState == .active {
                videoWriter.finish(at: presentationTime, { result in
                    switch result {
                    case .success:
                        print("video file success")
                        // we can add code to export or save the video file to Photos library here
                    case .failed(let error):
                        print("video file failure: \(error!.localizedDescription)")
                    }
                    self.videoWriteState = .inactive
                })
            }
            if audioWriteState == .active {
                audioWriter.finish(at: presentationTime, { result in
                    switch result {
                    case .success:
                        print("audio file success")
                        // we can add code to export the audio file here
                    case .failed(let error):
                        print("audio file failure: \(error!.localizedDescription)")
                    }
                    self.audioWriteState = .inactive
                })
            }
            // If all file writers are already inactive, change recording state to idle and end the background task
            if depthMapWriteState == .inactive && videoWriteState == .inactive && audioWriteState == .inactive {
                recordingState = .idle
                if let currentBackgroundRecordingID = self.backgroundRecordingID {
                    self.backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                    
                    if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                        UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                    }
                }
            }
            // Enable the Record button to let the user start another recording.
            DispatchQueue.main.async {
                if !self.recordButton.isEnabled {
                    self.recordButton.isEnabled = true
                    self.recordButton.setBackgroundImage(UIImage(systemName: "record.circle.fill"), for: [])
                }
            }
        default:
            break
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate and AVCaptureAudioDataOutputSampleBufferDelegate
    
    // Handle delegate method callback on receiving a sample buffer.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("sample buffer received")
        
        if recordingState != .idle {
            writeOutputToFile(output, sampleBuffer: sampleBuffer)
        }
        
        if output === videoDataOutput {
            performVisionRequests(on: sampleBuffer)
        }
            
    }
    
    // MARK: - Vision Preview Setup
    
    fileprivate func designatePreviewLayer() {
        let videoPreviewLayer = previewView.videoPreviewLayer
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        
        videoPreviewLayer.masksToBounds = true
        
        observationsOverlay = previewView
        
        //previewView.insertSubview(observationsOverlay, at: 0)
    }
    
    // MARK: - Performing Vision Requests
    
    func performVisionRequests(on sampleBuffer: CMSampleBuffer) {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // Hide the label when no face is observed
            DispatchQueue.main.async {
                self.qualityLabel.isHidden = true
                self.confidenceLabel.isHidden = true
            }
            // Nothing to track, so abort.
            return
        }
        
        // Perform face landmark tracking on detected faces.
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // Perform landmark detection on tracked faces.
        for trackingRequest in newTrackingRequests {
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                // NOTE: currently this means nil will never be fed to writeToCSV(), so instead of putting zeros it will just record nothing at all.
                // Missing frames can still be identified from the timestamp, though
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                      let results = landmarksRequest.results as? [VNFaceObservation] else {
                    return
                }
                
                // Get face landmarks confidence metric
                self.faceLandmarksConfidence = results[0].landmarks?.confidence
                let confidenceText = String(format: "%.3f", self.faceLandmarksConfidence!)
                // Update UI label on the main queue
                DispatchQueue.main.async {
                    self.confidenceLabel.isHidden = false
                    self.confidenceLabel.text = "Face Landmarks Confidence: " + confidenceText
                }
                
                // Write face observation results to file if collecting data.
                // Perform data collection in background queue so that it does not hold up the UI.
                if self.recordingState == .recording {
                    // NOTE: this only calls for the first observation in the array if there multiple
                    // Could make this so each face observation goes into a separate file (not necessary but safer)
                    if let depthData = self.depthData {
                        if self.faceLandmarksFileWriter != nil {
                            self.faceLandmarksFileWriter?.writeToCSV(faceObservation: results[0], depthData: depthData)
                        } else {
                            print("No face landmarks file writer found, failed to access writeToCSV().")
                        }
                    } else {
                        print("No depth data found.")
                    }
                }
                
                // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
                DispatchQueue.main.async {
                    self.displayFaceObservations(results)
                    self.updateIndicator()
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            
            // Continue to track detected facial landmarks.
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
            }
            
            // Get face rectangles request containing roll & yaw for alignment checking
            let faceRectanglesRequest = VNDetectFaceRectanglesRequest()
            do {
                try imageRequestHandler.perform([faceRectanglesRequest])
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectanglesRequest: %@", error)
            }
            if let face = faceRectanglesRequest.results?.first as? VNFaceObservation {
                self.isAligned = self.checkAlignment(of: face)
            } else {
                print("Could not check face alignment")
            }
            
            // Get face capture quality metric
            let faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest()
            faceCaptureQualityRequest.inputFaceObservations = [faceObservation]
            do {
                try imageRequestHandler.perform([faceCaptureQualityRequest])
            } catch let error as NSError {
                NSLog("Failed to perform FaceCaptureQualityRequest: %@", error)
            }
            
            guard let result = faceCaptureQualityRequest.results?.first as? VNFaceObservation,
                  let faceCaptureQuality = result.faceCaptureQuality else {
                print("Failed to produce face capture quality metric")
                return
            }
            
            self.faceCaptureQuality = faceCaptureQuality
            let qualityText = String(format: "%.2f", faceCaptureQuality)
            // Update UI label on the main queue
            DispatchQueue.main.async {
                self.qualityLabel.isHidden = false
                self.qualityLabel.text = "Face Capture Quality: " + qualityText
            }
        }
    }
    
    fileprivate func prepareVisionRequest() {
        
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        
        //self.setupVisionDrawingLayers()
    }
    
    // MARK: - Drawing Vision Observations
    
    func displayFaceObservations(_ faceObservations: [VNFaceObservation]) {
        let overlay = observationsOverlay
        DispatchQueue.main.async {
            var reusableViews = self.reusableFaceObservationOverlayViews
            for observation in faceObservations {
                // Reuse existing observation view if there is one.
                if let existingView = reusableViews.popLast() {
                    existingView.faceObservation = observation
                } else {
                    let newView = FaceObservationOverlayView(faceObservation: observation, videoResolution: self.videoResolution)
                    overlay.addSubview(newView)
                }
            }
            // Remove previously existing views that were not reused.
            for view in reusableViews {
                view.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Face Guidelines and Indicator
    
    private func updateIndicator() {
        if isAligned {
            indicatorImage.image = UIImage(systemName: "checkmark.square.fill")
            indicatorImage.tintColor = UIColor.systemGreen
        } else {
            indicatorImage.image = UIImage(systemName: "xmark.square")
            indicatorImage.tintColor = UIColor.systemRed
        }
    }
    
    private func checkAlignment(of faceObservation: VNFaceObservation) -> Bool {
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
        let rotationErrorMargin = rotation.radiansForDegrees()
        let rotationCondition = faceRoll.magnitude <= rotationErrorMargin && faceYaw.magnitude <= rotationErrorMargin
        
        let isAligned: Bool = centeredCondition && sizeCondition && rotationCondition
        
        return isAligned
    }
    
    // MARK: - Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    // MARK: - Helper Methods for Handling Device Orientation & EXIF
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}

extension CGFloat {
    func radiansForDegrees(/*_ degrees: CGFloat*/) -> CGFloat {
        return CGFloat(Double(self) * Double.pi / 180.0)
    }
}
