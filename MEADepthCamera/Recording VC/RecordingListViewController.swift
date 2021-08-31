//
//  RecordingListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListViewController: UITableViewController {
    
    // MARK: Properties
    
    @IBOutlet private weak var useCaseView: MainMenuUseCaseView!
    
    static let showDetailSegueIdentifier = "ShowRecordingDetailSegue"
    static let unwindFromCameraSegueIdentifier = "UnwindFromCameraSegue"
    static let showCameraSegueIdentifier = "ShowCameraSegue"
    static let mainStoryboardName = "Main"
    static let detailViewControllerIdentifier = "RecordingDetailViewController"
    
    private var recordingListDataSource: RecordingListDataSource?
    
    // State
    private var useCase: UseCase?
    private var isProcessing: Bool = false
    
    // MARK: Navigation
    
    func configure(with useCase: UseCase) {
        self.useCase = useCase
        recordingListDataSource = RecordingListDataSource(useCase: useCase, recordingDeletedAction: {
            // handle recording deleted
        }, recordingChangedAction: {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        })
        recordingListDataSource?.fetchTasks()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showDetailSegueIdentifier,
           let destination = segue.destination as? RecordingDetailViewController,
           let cell = sender as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            let rowIndex = indexPath.row
            guard let task = recordingListDataSource?.task(at: rowIndex),
                  let recording = recordingListDataSource?.recording(for: task) else {
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
            print("segue to camera")
            destination.useCase = useCase
            destination.task = recordingListDataSource?.task(at: rowIndex)
        }
    }
    
    @IBAction func unwindFromCamera(unwindSegue: UIStoryboardSegue) {
        
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = recordingListDataSource
        
        //navigationItem.setRightBarButton(editButtonItem, animated: false)
        navigationItem.title = recordingListDataSource?.title
        
        useCaseView.configure(title: useCase?.title, subjectIDText: useCase?.subjectID)
        
        // Search bar controller
//        let searchController = UISearchController(searchResultsController: nil)
//        searchController.searchResultsUpdater = recordingListDataSource
//        searchController.obscuresBackgroundDuringPresentation = false
//        navigationItem.searchController = searchController
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
           navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(false, animated: animated)
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        // Push the detail view when the info button is pressed.
        let storyboard = UIStoryboard(name: Self.mainStoryboardName, bundle: nil)
        let detailViewController: RecordingDetailViewController = storyboard.instantiateViewController(identifier: Self.detailViewControllerIdentifier)
        
        let rowIndex = indexPath.row
        guard let task = recordingListDataSource?.task(at: rowIndex),
              let recording = recordingListDataSource?.recording(for: task) else {
            fatalError("Couldn't find data source for use case list.")
        }
        
        detailViewController.configure(with: recording, editAction: { recording in
//            self.useCaseListDataSource?.update(useCase, at: rowIndex) { success in
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
    
}
