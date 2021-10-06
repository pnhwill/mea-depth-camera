//
//  RecordingDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/23/21.
//

import UIKit

class RecordingDetailViewController: UITableViewController {
    

}

/*
 
 typealias RecordingChangeAction = (Recording) -> Void
 
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
     self.processorSettings = recording.processorSettings
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
extension RecordingListViewController: FaceLandmarksPipelineDelegate {
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

extension RecordingListViewController {
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

 
 
 // MARK: Properties
 
 @IBOutlet private weak var useCaseView: UseCaseSummaryView!
 
 static let showDetailSegueIdentifier = "ShowRecordingDetailSegue"
 static let unwindFromCameraSegueIdentifier = "UnwindFromCameraSegue"
 static let showCameraSegueIdentifier = "ShowCameraSegue"
 static let mainStoryboardName = "Main"
 static let detailViewControllerIdentifier = "RecordingDetailViewController"
 
 private var dataSource: RecordingListDataSource?
 
 // State
 private var useCase: UseCase?
 //private var isProcessing: Bool = false
 
 // MARK: Navigation
 
 func configure(with useCase: UseCase) {
     self.useCase = useCase
     dataSource = RecordingListDataSource(useCase: useCase, recordingDeletedAction: {
         // handle recording deleted
     }, recordingChangedAction: {
         DispatchQueue.main.async {
             self.tableView.reloadData()
         }
     })
     //dataSource?.fetchTasks()
 }
 
 override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     if segue.identifier == Self.showDetailSegueIdentifier,
        let destination = segue.destination as? RecordingDetailViewController,
        let cell = sender as? UITableViewCell,
        let indexPath = tableView.indexPath(for: cell) {
         let rowIndex = indexPath.row
         guard let task = dataSource?.task(at: rowIndex),
               let recording = dataSource?.recording(for: task) else {
             fatalError("Couldn't find data source for recording list.")
         }
         destination.configure(with: recording, editAction: { recording in
//                self.recordingListDataSource?.update(recording, at: rowIndex) { success in
//                    if success {
//                        DispatchQueue.main.async {
//                            self.tableView.reloadData()
//                        }
//                    } else {
//                        DispatchQueue.main.async {
//                            let alertTitle = NSLocalizedString("Can't Update Recording", comment: "error updating recording title")
//                            let alertMessage = NSLocalizedString("An error occured while attempting to update the recording.", comment: "error updating recording message")
//                            let actionTitle = NSLocalizedString("OK", comment: "ok action title")
//                            let actions = [UIAlertAction(title: actionTitle, style: .default, handler: { _ in
//                                self.dismiss(animated: true, completion: nil)
//                            })]
//                            self.alert(title: alertTitle, message: alertMessage, actions: actions)
//                        }
//                    }
//                }
         })
     }
     if segue.identifier == Self.showCameraSegueIdentifier,
        let destination = segue.destination as? CameraViewController,
        let button = sender as? UIButton,
        let cell = button.superview?.superview?.superview as? UITableViewCell,
        let indexPath = tableView.indexPath(for: cell) {
         let rowIndex = indexPath.row
         destination.useCase = useCase
         destination.task = dataSource?.task(at: rowIndex)
     }
 }
 
 @IBAction func unwindFromCamera(unwindSegue: UIStoryboardSegue) {
     print("unwind from camera")
     tableView.reloadData()
 }
 
 // MARK: Life Cycle
 
 override func viewDidLoad() {
     super.viewDidLoad()

     tableView.dataSource = dataSource
     
     //navigationItem.setRightBarButton(editButtonItem, animated: false)
     navigationItem.title = dataSource?.title
     let titleText = [useCase?.experiment?.title, useCase?.title].compactMap { $0 }.joined(separator: ": ")
     useCaseView.configure(title: titleText, subjectIDText: useCase?.subjectID)
     
     // Search bar controller
//        let searchController = UISearchController(searchResultsController: nil)
//        searchController.searchResultsUpdater = recordingListDataSource
//        searchController.obscuresBackgroundDuringPresentation = false
//        navigationItem.searchController = searchController
 }
 
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        if let navigationController = navigationController,
//           navigationController.isToolbarHidden {
//            navigationController.setToolbarHidden(false, animated: animated)
//        }
//    }
 
 override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
     // Push the detail view when the info button is pressed.
     let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
     let detailViewController: RecordingDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
     
     let rowIndex = indexPath.row
     guard let task = dataSource?.task(at: rowIndex),
           let recording = dataSource?.recording(for: task) else {
         fatalError("Couldn't find data source for use case list.")
     }
     
     detailViewController.configure(with: recording, editAction: { recording in
//            self.recordingListDataSource?.update(useCase, at: rowIndex) { success in
//                if success {
//                    DispatchQueue.main.async {
//                        self.tableView.reloadData()
//                    }
//                } else {
//                    DispatchQueue.main.async {
//                        let alertTitle = NSLocalizedString("Can't Update Use Case", comment: "error updating use case title")
//                        let alertMessage = NSLocalizedString("An error occured while attempting to update the use case.", comment: "error updating use case message")
//                        let actionTitle = NSLocalizedString("OK", comment: "ok action title")
//                        let actions = [UIAlertAction(title: actionTitle, style: .default, handler: { _ in
//                            self.dismiss(animated: true, completion: nil)
//                        })]
//                        self.alert(title: alertTitle, message: alertMessage, actions: actions)
//                    }
//                }
//            }
     })
     navigationController?.pushViewController(detailViewController, animated: true)
 }
 
 // MARK: Edit Mode
 
//    fileprivate func transitionToViewMode(_ useCase: UseCase) {
//        if isProcessing {
//            navigationItem.title = NSLocalizedString("Processing Recordings", comment: "processing recordings nav title")
//            editButtonItem.isEnabled = false
//        } else {
//            recordingListDataSource?.selectedRecordings.removeAll()
//            navigationItem.title = NSLocalizedString("Review Recordings", comment: "review recordings nav title")
//            editButtonItem.isEnabled = true
//        }
//        navigationItem.leftBarButtonItem = nil
//        editButtonItem.title = NSLocalizedString("Select", comment: "select edit button title")
//    }
//
//    fileprivate func transitionToEditMode(_ useCase: UseCase) {
//        navigationItem.title = NSLocalizedString("Select Recordings", comment: "select recordings nav title")
//        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTrigger))
//        editButtonItem.title = NSLocalizedString("Process", comment: "process edit button title")
//    }
//
//    override func setEditing(_ editing: Bool, animated: Bool) {
//        super.setEditing(editing, animated: animated)
//        guard let useCase = useCase else {
//            fatalError("No use case found")
//        }
//        if editing {
//            transitionToEditMode(useCase)
//        } else {
//            transitionToViewMode(useCase)
//        }
//    }
//
//    @objc
//    func cancelButtonTrigger() {
//        isProcessing = false
//        setEditing(false, animated: true)
//    }
 
//    // MARK: Cell Selection
//
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        guard let recordingListDataSource = recordingListDataSource, let cell = tableView.cellForRow(at: indexPath) else { return }
//
//        // Unselect the row, and instead, show the state with a checkmark.
//        tableView.deselectRow(at: indexPath, animated: false)
//
//        recordingListDataSource.selectRecording(at: indexPath.row)
//
//        if recordingListDataSource.isSelected(at: indexPath.row) {
//            cell.accessoryType = .checkmark
//        } else {
//            cell.accessoryType = .none
//        }
//
//        let isAnyRecordingsSelected = !recordingListDataSource.selectedRecordings.isEmpty
//        editButtonItem.isEnabled = isAnyRecordingsSelected
//        isProcessing = isAnyRecordingsSelected
//    }
 */
