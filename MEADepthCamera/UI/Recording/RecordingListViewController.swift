//
//  RecordingListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListViewController: UITableViewController {
    
    @IBOutlet private weak var useCaseView: UseCaseSummaryView!
    
    private var dataSource: RecordingListDataSource?
    private var useCase: UseCase?
    
    // Post-Processing
    private var faceLandmarksPipelines: [FaceLandmarksPipeline] = []
    private var trackingState: TrackingState = .stopped {
        didSet {
            self.handleTrackingStateChange()
        }
    }
    let visionTrackingQueue = DispatchQueue(label: "vision tracking queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func configure(useCase: UseCase, task: Task) {
        self.useCase = useCase
        dataSource = RecordingListDataSource(useCase: useCase, task: task)
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = dataSource
        navigationItem.title = dataSource?.navigationTitle
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshUseCaseView()
    }
    
    private func refreshUseCaseView() {
        let titleText = [useCase?.experiment?.title, useCase?.title].compactMap { $0 }.joined(separator: ": ")
        useCaseView.configure(title: titleText, subjectIDText: useCase?.subjectID)
    }
    
}

// MARK: UITableViewDelegate
extension RecordingListViewController {
    static let processingHeaderNibName = "ProcessingView"
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 0
        default:
            return 55
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return nil
        default:
            guard let isProcessed = dataSource?.isRecordingProcessed(at: section), !isProcessed else { return nil }

            guard let views = Bundle.main.loadNibNamed(Self.processingHeaderNibName, owner: self, options: nil),
                  let processingHeaderView = views[0] as? ProcessingView else { return nil }

            processingHeaderView.section = section
            let displayText = "Tap to Start Processing"
            processingHeaderView.configure(isProcessing: false, frameCounterText: displayText, progress: nil, startStopAction: { section in
                self.handleStartStopButton(in: section)
            })
            return processingHeaderView
        }
    }
}

// MARK: Face Landmarks Processing
extension RecordingListViewController {
    
    private func handleStartStopButton(in section: Int) {
        switch trackingState {
        case .tracking:
            // Stop tracking
            self.faceLandmarksPipelines[section].cancelTracking()
            self.trackingState = .stopped
        case .stopped:
            // Initialize processor and start tracking
            self.trackingState = .tracking
            guard let recording = dataSource?.recording(at: section) else {
                print("Failed to start tracking: recording not found")
                return
            }
            visionTrackingQueue.async {
                self.startTracking(recording)
            }
        }
    }
    
    private func startTracking(_ recording: Recording) {
        guard let processorSettings = recording.processorSettings else {
            print("Failed to start tracking: processor settings not found")
            return
        }
        let newFaceLandmarksPipeline = FaceLandmarksPipeline(recording: recording, processorSettings: processorSettings)
        newFaceLandmarksPipeline.delegate = self
        faceLandmarksPipelines.append(newFaceLandmarksPipeline)
        do {
            try newFaceLandmarksPipeline.startTracking()
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
//        var processingHeaderHidden: Bool!
//        switch trackingState {
//        case .stopped:
//            processingHeaderHidden = isProcessed
//            processingHeaderView.configure(isProcessing: false, totalFrames: 0, processedFrames: 0, startStopAction: {
//                self.handleStartStopButton()
//            })
//        case .tracking:
//            processingHeaderHidden = false
//        }
//        UIView.animate(withDuration: 0.5, animations: {
//            self.view.layoutIfNeeded()
//            self.processingHeaderView.isHidden = processingHeaderHidden
//        })
    }
}

// MARK: FaceLandmarksPipelineDelegate
extension RecordingListViewController: FaceLandmarksPipelineDelegate {
    func displayFrameCounter(_ frame: Int, totalFrames: Int) {
//        processingHeaderView.configure(isProcessing: true, totalFrames: totalFrames, processedFrames: frame, startStopAction: {
//            self.handleStartStopButton()
//        })
    }
    
    func didFinishTracking(success: Bool) {
//        isProcessed = success
//        DispatchQueue.main.async {
//            self.trackingState = .stopped
//        }
//        if let recording = recording {
//            let context = recording.managedObjectContext
//            if isProcessed {
//                persistentContainer?.saveContext(backgroundContext: context)
//            } else {
//                context?.rollback()
//            }
//            context?.refresh(recording, mergeChanges: true)
//        }
    }
}
