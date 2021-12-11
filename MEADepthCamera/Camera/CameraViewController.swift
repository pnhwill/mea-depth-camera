//
//  CameraViewController.swift
//  MEADepthCamera
//
//  Created by Will on 7/13/21.
//

import UIKit
import AVFoundation
import Vision

/// A view controller that displays the camera preview, manages camera controls, and contains an embedded audio visualizer view controller.
class CameraViewController: UIViewController {
    
    // MARK: - Properties
    
    // Video preview view
    @IBOutlet private weak var previewView: PreviewMetalView!
    
    // UI buttons/labels
    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    @IBOutlet private weak var resumeButton: UIButton!
    @IBOutlet private weak var recordButton: UIButton!
    
    @IBOutlet private weak var faceGuideView: FaceGuideView!
    
    // Navigation bar button
    @IBOutlet private weak var doneButton: UIBarButtonItem!
    
    // Post-processing in progress
    private lazy var spinner: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .systemBlue
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private var audioVisualizerViewController: AudioVisualizerViewController?

    // AVCapture session
    @objc private var sessionManager: CaptureSessionManager!
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(
        label: Bundle.main.reverseDNS("sessionQueue"),
        autoreleaseFrequency: .workItem)
    
    private var renderingEnabled = true
    
    // Capture data output delegate
    private var capturePipeline: CapturePipeline?
    
    // Movie recording
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    // Use case and task
    private var useCase: UseCase!
    private var task: Task!
    
    // Face guidelines alignment
    private var isAligned: Bool = false {
        didSet {
            self.updateIndicator()
        }
    }
    
    // KVO
    private var keyValueObservations = [NSKeyValueObservation]()
    
    // MARK: Overrides
    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    // MARK: - Configuration
    
    func configure(useCase: UseCase, task: Task) {
        self.useCase = useCase
        self.task = task
    }
    
    @IBSegueAction func loadAudioVisualizerVC(_ coder: NSCoder) -> AudioVisualizerViewController? {
        let audioVisualizerViewController = AudioVisualizerViewController(coder: coder)
        self.audioVisualizerViewController = audioVisualizerViewController
        return audioVisualizerViewController
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = task.name
        // Disable the UI. Enable the UI later, if and only if the session starts running.
        recordButton.isEnabled = false
        //doneButton.isEnabled = false
        
        sessionQueue.async {
            self.sessionManager = CaptureSessionManager()
        }
        
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
            self.sessionManager.configureSession { videoDevice, videoDataOutput, depthDataOutput, audioDataOutput in
                // Initialize the data output processor
                self.capturePipeline = CapturePipeline(
                    delegate: self,
                    useCase: self.useCase,
                    task: self.task,
                    videoDataOutput: videoDataOutput,
                    depthDataOutput: depthDataOutput,
                    audioDataOutput: audioDataOutput
                )
                self.capturePipeline?.configureProcessors(for: videoDevice)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Configure the progress spinner
        if spinner.superview == nil {
            view.addSubview(spinner)
            view.bringSubviewToFront(spinner)
            spinner.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height / 2)
        }
        
        navigationController?.setToolbarHidden(true, animated: false)
        
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
                
                self.addObservers()
                
                self.capturePipeline?.dataOutputQueue.async {
                    self.renderingEnabled = true
                }
                
                self.sessionManager.session.startRunning()
                self.isSessionRunning = self.sessionManager.session.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("\(Bundle.main.applicationName) doesn't have permission to use the camera, please change privacy settings",
                                                    comment: "Alert message when the user has denied access to the camera")
                    let actions = [
                    UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil),
                    UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                                                            })]
                    self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let actions = [UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil)]
                    self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        capturePipeline?.dataOutputQueue.async {
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

    @objc
    func didEnterBackground(notification: NSNotification) {
        // Free up resources.
        capturePipeline?.dataOutputQueue.async {
            self.renderingEnabled = false
            self.capturePipeline?.videoDepthConverter.reset()
            self.previewView.pixelBuffer = nil
            self.previewView.flushTextureCache()
        }
    }
    
    @objc
    func willEnterForeground(notification: NSNotification) {
        capturePipeline?.dataOutputQueue.async {
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
    
    private func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            let message = NSLocalizedString("Thermal state: \(state.thermalStateString)", comment: "Alert message when thermal state has changed")
            let actions = [UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)]
            self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
        }
    }
    
    // MARK: - KVO and Notifications
    
    private func addObservers() {
        
        let sessionRunningObservation = sessionManager.session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            
            DispatchQueue.main.async {
                self.recordButton.isEnabled = isSessionRunning && self.capturePipeline != nil
            }
        }
        keyValueObservations.append(sessionRunningObservation)
        
        let systemPressureStateObservation = observe(\.sessionManager.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.pressureStateChanged(systemPressureState: systemPressureState)
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
                    let actions = [UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)]
                    self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
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
    
    private func pressureStateChanged(systemPressureState: AVCaptureDevice.SystemPressureState) {
        // Take action to reduce pressure level e.g. reduce framerate, resolution, disable depth, etc.
        DispatchQueue.main.async {
            self.displayPressureState(systemPressureState: systemPressureState)
        }
    }
    
    private func displayPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        //let pressureFactors = systemPressureState.factors
        print("System pressure state is now \(systemPressureState.pressureLevelString)")
        let message = NSLocalizedString("System pressure level: \(systemPressureState.pressureLevelString)", comment: "Alert message when system pressure level has changed")
        let actions = [UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)]
        self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
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
        capturePipeline?.dataOutputQueue.async {
            defer {
                DispatchQueue.main.async {
                    // Enable the Record button to let the user stop or start another recording
                    self.recordButton.isEnabled = true
                    if let capturePipeline = self.capturePipeline {
                        self.updateRecordButtonWithRecordingState(capturePipeline.recordingState)
                    }
                    self.updateIndicator()
                }
            }
            
            switch self.capturePipeline?.recordingState {
            case .idle:
                // Only let recording start if the face is aligned
                guard self.isAligned else { return }
                // Start background task so that recording can always finish in the background
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                // Hide the navigation bar back button and update title
                DispatchQueue.main.async {
                    self.navigationItem.setHidesBackButton(true, animated: true)
                }
                self.capturePipeline?.startRecording()
                
            case .recording:
                self.capturePipeline?.stopRecording()
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
    
    private func updateRecordButtonWithRecordingState(_ recordingState: CapturePipeline.RecordingState) {
        var recordButtonImage: UIImage?
        switch recordingState {
        case .idle, .finish:
            recordButtonImage = UIImage(systemName: "record.circle.fill")
        case .recording, .start:
            recordButtonImage = UIImage(systemName: "stop.circle")
        }
        recordButton.setBackgroundImage(recordButtonImage, for: [])
    }
    
    // MARK: - Face Alignment Indicator
    
    private func updateIndicator() {
        guard renderingEnabled else { return }
        DispatchQueue.main.async {
            switch self.capturePipeline?.recordingState {
            case .recording, .start:
                self.faceGuideView.outlineColor = .white
            default:
                self.faceGuideView.outlineColor = self.isAligned ? .green : .red
            }
        }
    }
}

// MARK: - CapturePipelineDelegate
extension CameraViewController: CapturePipelineDelegate {
    
    func previewPixelBufferReadyForDisplay(_ previewPixelBuffer: CVPixelBuffer) {
        guard renderingEnabled else { return }
        previewView.pixelBuffer = previewPixelBuffer
    }
    
    func setFaceAlignment(_ isAligned: Bool) {
        self.isAligned = isAligned
    }
    
    func audioSampleBufferReadyForDisplay(_ sampleBuffer: CMSampleBuffer) {
        guard renderingEnabled else { return }
        audioVisualizerViewController?.renderAudio(sampleBuffer)
    }
    
    func capturePipelineRecordingDidStop() {
        
    }
}
