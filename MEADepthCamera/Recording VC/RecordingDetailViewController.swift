//
//  RecordingDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/23/21.
//

import UIKit

class RecordingDetailViewController: UITableViewController {
    
    typealias RecordingChangeAction = (Recording) -> Void
    
    @IBOutlet private weak var processingHeaderView: ProcessingView!
    
    // Current recording
    private var recording: Recording?
    private var isNew = false
    private var isProcessed = false
    
    private var dataSource: UITableViewDataSource?
    private var recordingEditAction: RecordingChangeAction?
    private var recordingAddAction: RecordingChangeAction?
    
    // Core Data
    var persistentContainer: PersistentContainer?
    
    // Face Landmarks Processing
    var processorSettings: ProcessorSettings?
    private var faceLandmarksPipeline: FaceLandmarksPipeline?
    private var trackingState: TrackingState = .stopped {
        didSet {
            self.handleTrackingStateChange()
        }
    }
    let visionTrackingQueue = DispatchQueue(label: "vision tracking queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func configure(with recording: Recording, isNew: Bool = false, addAction: RecordingChangeAction? = nil, editAction: RecordingChangeAction? = nil) {
        self.recording = recording
        self.isNew = isNew
        self.isProcessed = recording.isProcessed
        self.recordingAddAction = addAction
        self.recordingEditAction = editAction
        if isViewLoaded {
            setEditing(isNew, animated: false)
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setEditing(isNew, animated: false)
        processingHeaderView.configure(isProcessing: false, totalFrames: 0, processedFrames: 0, startStopAction: {
            self.handleStartStopButton()
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
            !navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(true, animated: animated)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        faceLandmarksPipeline?.cancelTracking()
        super.viewWillDisappear(animated)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        guard let recording = recording else {
            fatalError("No recording found for detail view")
        }
        dataSource = RecordingDetailViewDataSource(recording: recording)
        navigationItem.title = NSLocalizedString("View Recording", comment: "view recording nav title")
        tableView.dataSource = dataSource
        tableView.reloadData()
    }
    
    // MARK: Face Landmarks Processing
    private func startTracking() {
        guard let recording = recording, let processorSettings = processorSettings else {
            print("Failed to start tracking: recording or processor settings not found")
            return
        }
        faceLandmarksPipeline = FaceLandmarksPipeline(recording: recording, processorSettings: processorSettings)
        faceLandmarksPipeline?.delegate = self
        do {
            try faceLandmarksPipeline?.startTracking()
        } catch {
            self.handleTrackerError(error)
        }
    }
    
    private func handleTrackerError(_ error: Error) {
        DispatchQueue.main.async {
            var messageHeader: String
            if error is VisionTrackerProcessorError {
                messageHeader = "Vision Processor Error"
            } else {
                messageHeader = "Error"
            }
            let message: String = messageHeader + ": " + error.localizedDescription
            let actions = [UIAlertAction(title: "OK", style: .cancel, handler: nil)]
            self.alert(title: Bundle.main.applicationName, message: message, actions: actions)
        }
    }
    
    private func handleTrackingStateChange() {
        var processingHeaderHidden: Bool!
        switch trackingState {
        case .stopped:
            processingHeaderHidden = isProcessed
            processingHeaderView.configure(isProcessing: false, totalFrames: 0, processedFrames: 0, startStopAction: {
                self.handleStartStopButton()
            })
        case .tracking:
            processingHeaderHidden = false
        }
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
            self.processingHeaderView.isHidden = processingHeaderHidden
        })
    }
    
    private func handleStartStopButton() {
        switch trackingState {
        case .tracking:
            // Stop tracking
            self.faceLandmarksPipeline?.cancelTracking()
            self.trackingState = .stopped
        case .stopped:
            // Initialize processor and start tracking
            self.trackingState = .tracking
            visionTrackingQueue.async {
                self.startTracking()
            }
        }
    }
}

// MARK: FaceLandmarksPipelineDelegate
extension RecordingDetailViewController: FaceLandmarksPipelineDelegate {
    func displayFrameCounter(_ frame: Int, totalFrames: Int) {
        processingHeaderView.configure(isProcessing: true, totalFrames: totalFrames, processedFrames: frame, startStopAction: {
            self.handleStartStopButton()
        })
    }
    
    func didFinishTracking(success: Bool) {
        isProcessed = success
        DispatchQueue.main.async {
            self.trackingState = .stopped
        }
        if let recording = recording {
            let context = recording.managedObjectContext
            if isProcessed {
                persistentContainer?.saveContext(backgroundContext: context)
            } else {
                context?.rollback()
            }
            context?.refresh(recording, mergeChanges: true)
        }
    }
}

// MARK: UITableViewController

extension RecordingDetailViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if isEditing {
            cell.backgroundColor = .tertiarySystemGroupedBackground
//            guard let editRow = UseCaseDetailEditDataSource.UseCaseRow(rawValue: indexPath.row) else {
//                return
//            }
        } else {
            cell.backgroundColor = .systemGroupedBackground
            guard let viewRow = UseCaseDetailViewDataSource.UseCaseRow(rawValue: indexPath.row) else {
                return
            }
            if viewRow == .title {
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
            } else {
                cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            }
        }
    }
}
