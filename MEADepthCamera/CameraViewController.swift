//
//  ViewController.swift
//  MEADepthCamera
//
//  Created by Will on 7/13/21.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {
    
    // MARK: - Properties
    
    // Video preview view
    @IBOutlet private(set) weak var previewView: PreviewMetalView!
    
    // UI buttons/labels
    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    @IBOutlet private weak var resumeButton: UIButton!
    @IBOutlet private weak var recordButton: UIButton!
    
    @IBOutlet private weak var qualityLabel: UILabel!
    @IBOutlet private weak var confidenceLabel: UILabel!
    
    @IBOutlet private weak var indicatorImage: UIImageView!
    
    // Capture data output delegate
    private var dataOutputProcessor: DataOutputProcessor?
    
    // AVCapture session
    @objc private var sessionManager: CaptureSessionManager!
    
    private var isSessionRunning = false
    
    // Movie recording
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    var renderingEnabled = true
    
    // Vision requests
    var detectionRequests: [VNDetectFaceRectanglesRequest]?
    var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // Layer UI for drawing Vision results
    var previewLayer: CALayer?
    
    var reusableFaceObservationOverlayViews: [FaceObservationOverlayView] {
        if let existingViews = previewView.subviews as? [FaceObservationOverlayView] {
            return existingViews
        } else {
            return [FaceObservationOverlayView]()
        }
    }
    
    enum TrackingState {
        case tracking
        case stopped
    }
    var trackingState: TrackingState = .stopped {
        didSet {
            self.handleTrackingStateChange()
        }
    }
    
    // Face guidelines alignment
    var isAligned: Bool = false
    
    // Dispatch queues
    var sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    var dataOutputQueue = DispatchQueue(label: "synchronized data output queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var videoOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var audioOutputQueue = DispatchQueue(label: "audio data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var depthOutputQueue = DispatchQueue(label: "depth data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    var visionTrackingQueue = DispatchQueue(label: "vision tracking queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // KVO
    private var keyValueObservations = [NSKeyValueObservation]()
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the UI. Enable the UI later, if and only if the session starts running.
        recordButton.isEnabled = false
        
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
                    self.sessionManager.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            }
        default:
            // The user has previously denied access.
            sessionManager.setupResult = .notAuthorized
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
            self.sessionManager = CaptureSessionManager(cameraViewController: self)
            self.sessionManager.configureSession()
            self.dataOutputProcessor = self.sessionManager.dataOutputProcessor
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let mainWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let interfaceOrientation = mainWindowScene?.interfaceOrientation ?? .portrait
        //statusBarOrientation = interfaceOrientation
        
        let initialThermalState = ProcessInfo.processInfo.thermalState
        if initialThermalState == .serious || initialThermalState == .critical {
            showThermalState(state: initialThermalState)
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        sessionQueue.async {
            switch self.sessionManager.setupResult {
            case .success:
                
                // Only setup observers and start the session running if setup succeeded
                DispatchQueue.main.async {
                    self.designatePreviewLayer()
                }
                
                // Set up preview Metal View orientation
                if let unwrappedVideoDataOutputConnection = self.sessionManager.videoDataOutput.connection(with: .video) {
                    let videoDevicePosition = self.sessionManager.videoDeviceInput.device.position
                    let rotation = PreviewMetalView.Rotation(with: interfaceOrientation,
                                                             videoOrientation: unwrappedVideoDataOutputConnection.videoOrientation,
                                                             cameraPosition: videoDevicePosition)
                    self.previewView.mirroring = (videoDevicePosition == .front)
                    if let rotation = rotation {
                        self.previewView.rotation = rotation
                    }
                }
                
                self.dataOutputProcessor?.configureProcessors()
                
                self.addObservers()
                
                self.depthOutputQueue.async {
                    self.renderingEnabled = true
                }
                
                self.sessionManager.session.startRunning()
                self.isSessionRunning = self.sessionManager.session.isRunning
                
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
        dataOutputProcessor?.visionProcessor?.cancelTracking()
        self.depthOutputQueue.async {
            self.renderingEnabled = false
        }
        sessionQueue.async {
            if self.sessionManager.setupResult == .success {
                self.sessionManager.session.stopRunning()
                self.isSessionRunning = self.sessionManager.session.isRunning
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

    @objc
    func didEnterBackground(notification: NSNotification) {
        // Free up resources.
        dataOutputQueue.async {
            self.renderingEnabled = false
            self.dataOutputProcessor?.visionProcessor?.reset()
            //self.dataOutputProcessor.videoDepthConverter.reset()
            self.previewView.pixelBuffer = nil
            self.previewView.flushTextureCache()
        }
    }
    
    @objc
    func willEnterForeground(notification: NSNotification) {
        dataOutputQueue.async {
            self.renderingEnabled = true
        }
    }
    
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
        
        let sessionRunningObservation = sessionManager.session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            
            DispatchQueue.main.async {
                self.recordButton.isEnabled = isSessionRunning// && self.movieFileOutput != nil
            }
        }
        keyValueObservations.append(sessionRunningObservation)
        
        let systemPressureStateObservation = observe(\.sessionManager.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: sessionManager.videoDeviceInput.device)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: NSNotification.Name.AVCaptureSessionRuntimeError,
                                               object: sessionManager.session)
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
                                               object: sessionManager.session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
                                               object: sessionManager.session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    // MARK: - Session Management
    
    @IBAction private func resumeInterruptedSession(_ sender: UIButton) {
        sessionQueue.async {
            /*
             The session might fail to start running, for example, if a phone or FaceTime call is still
             using audio or video. This failure is communicated by the session posting a
             runtime error notification. To avoid repeatedly failing to start the session,
             only try to restart the session in the error handler if you aren't
             trying to resume the session.
             */
            self.sessionManager.session.startRunning()
            self.isSessionRunning = self.sessionManager.session.isRunning
            if !self.sessionManager.session.isRunning {
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
                    self.sessionManager.session.startRunning()
                    self.isSessionRunning = self.sessionManager.session.isRunning
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
    
    // MARK: - Device Control
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.sessionManager.videoDeviceInput.device
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
    
    // MARK: - Toggle Recording
    
    @IBAction private func toggleRecording(_ sender: UIButton) {
        // Don't let the user spam the button
        // Disable the Record button until recording starts or finishes.
        recordButton.isEnabled = false
        dataOutputQueue.async {
            defer {
                DispatchQueue.main.async {
                    // Enable the Record button to let the user stop or start another recording
                    self.recordButton.isEnabled = true
                    if let dataProcessor = self.dataOutputProcessor {
                        self.updateRecordButtonWithRecordingState(dataProcessor.recordingState)
                    }
                }
            }
            
            switch self.dataOutputProcessor?.recordingState {
            case .idle:
                // Only let recording start if the face is aligned
                guard self.isAligned else {
                    print("Face is not aligned")
                    return
                }
                // Start background task so that recording can always finish in the background
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                self.dataOutputProcessor?.startRecording()
                
            case .recording:
                self.dataOutputProcessor?.stopRecording()
                if let currentBackgroundRecordingID = self.backgroundRecordingID {
                    self.backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                    if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                        UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                    }
                }
            default:
                return
            }
        }
    }
    
    private func updateRecordButtonWithRecordingState(_ recordingState: RecordingState) {
        var isRecording: Bool {
            switch recordingState {
            case .idle, .finish:
                return false
            case .recording, .start:
                return true
            }
        }
        //let color = isRecording ? UIColor.red : UIColor.yellow
        //let title = isRecording ? "Stop" : "Record"
        //recordButton.tintColor = color
        //recordButton.setTitleColor(color, for: .normal)
        //recordButton.setTitle(title, for: .normal)
        let image = isRecording ? UIImage(systemName: "stop.circle") : UIImage(systemName: "record.circle.fill")
        recordButton.setBackgroundImage(image, for: [])
    }
    
    // MARK: - Vision Preview Setup
    
    fileprivate func designatePreviewLayer() {
        let videoPreviewLayer = previewView.layer
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.contentsGravity = .resizeAspect
        
        videoPreviewLayer.masksToBounds = true
    }
    
    // MARK: - Vision Face Overlay Methods
    
    func displayMetrics(confidence: VNConfidence?, captureQuality: Float?) {
        guard renderingEnabled else {
            return
        }
        // Update UI labels on the main queue
        DispatchQueue.main.async {
            if let confidence = confidence {
                self.confidenceLabel.isHidden = false
                let confidenceText = String(format: "%.3f", confidence)
                self.confidenceLabel.text = "Face Landmarks Confidence: " + confidenceText
            }
            
            if let captureQuality = captureQuality {
                self.qualityLabel.isHidden = false
                let qualityText = String(format: "%.2f", captureQuality)
                self.qualityLabel.text = "Face Capture Quality: " + qualityText
            }
        }
    }
    
    func displayFaceObservations(_ faceObservation: VNFaceObservation) {
        guard let rootView = previewView, renderingEnabled else {
            print("Preview view not found/rendering disabled")
            return
        }
        DispatchQueue.main.async {
            var reusableViews = self.reusableFaceObservationOverlayViews
            // Reuse existing observation view if there is one.
            if let existingView = reusableViews.popLast() {
                existingView.faceObservation = faceObservation
            } else {
                let newView = FaceObservationOverlayView(faceObservation: faceObservation, settings: self.sessionManager.processorSettings)
                rootView.addSubview(newView)
            }
        }
    }
    
    private func handleTrackingStateChange() {
        switch trackingState {
        case .tracking:
            return
        case .stopped:
            DispatchQueue.main.async {
                // Hide the labels
                self.qualityLabel.isHidden = true
                self.confidenceLabel.isHidden = true

                // Remove previously existing views that were not reused.
                for view in self.reusableFaceObservationOverlayViews {
                    view.removeFromSuperview()
                }
            }
        }
    }
    
    
    // MARK: - Face Guidelines and Indicator
    
    func updateIndicator() {
        indicatorImage.image = isAligned ? UIImage(systemName: "checkmark.square.fill") : UIImage(systemName: "xmark.square")
        indicatorImage.tintColor = isAligned ? UIColor.systemGreen : UIColor.systemRed
    }
    
    // MARK: - Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
}

// MARK: - PreviewMetalView.Rotation Extension

extension PreviewMetalView.Rotation {
    
    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevice.Position) {
        /*
         Calculate the rotation between the videoOrientation and the interfaceOrientation.
         The direction of the rotation depends upon the camera position.
         */
        switch videoOrientation {
            
        case .portrait:
            switch interfaceOrientation {
            case .landscapeRight:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            case .landscapeLeft:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            case .portrait:
                self = .rotate0Degrees
                
            case .portraitUpsideDown:
                self = .rotate180Degrees
                
            default: return nil
            }
            
        case .portraitUpsideDown:
            switch interfaceOrientation {
            case .landscapeRight:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            case .landscapeLeft:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            case .portrait:
                self = .rotate180Degrees
                
            case .portraitUpsideDown:
                self = .rotate0Degrees
                
            default: return nil
            }
            
        case .landscapeRight:
            switch interfaceOrientation {
            case .landscapeRight:
                self = .rotate0Degrees
                
            case .landscapeLeft:
                self = .rotate180Degrees
                
            case .portrait:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            case .portraitUpsideDown:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            default: return nil
            }
            
        case .landscapeLeft:
            switch interfaceOrientation {
            case .landscapeLeft:
                self = .rotate0Degrees
                
            case .landscapeRight:
                self = .rotate180Degrees
                
            case .portrait:
                self = cameraPosition == .front ? .rotate90Degrees : .rotate270Degrees
                
            case .portraitUpsideDown:
                self = cameraPosition == .front ? .rotate270Degrees : .rotate90Degrees
                
            default: return nil
            }
        @unknown default:
            fatalError("Unknown orientation. Can't continue.")
        }
    }
}

// MARK: VisionTrackerProcessor Extension

extension VisionTrackerProcessor {
    // MARK: Helper Methods for Handling Device Orientation & EXIF
    
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
