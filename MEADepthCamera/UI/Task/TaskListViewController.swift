//
//  TaskListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 9/13/21.
//

import UIKit

class TaskListViewController: UITableViewController {
    
    // MARK: Properties
    
    @IBOutlet private weak var useCaseView: UseCaseSummaryView!
    
    static let showCameraSegueIdentifier = "ShowCameraSegue"
    static let unwindFromCameraSegueIdentifier = "UnwindFromCameraSegue"
    static let showRecordingsSegueIdentifier = "ShowRecordingListSegue"
    static let showInstructionsSegueIdentifier = "ShowInstructionsSegue"
    static let recordingsViewControllerIdentifier = "RecordingListViewController"
    
    private var dataSource: TaskListDataSource?
    private var useCase: UseCase?
    
    // MARK: Navigation
    
    func configure(with useCase: UseCase) {
        self.useCase = useCase
        dataSource = TaskListDataSource(useCase: useCase)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showCameraSegueIdentifier,
           let destination = segue.destination as? CameraViewController,
           let button = sender as? UIButton,
           let cell = button.superview?.superview?.superview as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            let rowIndex = indexPath.row
            guard let task = dataSource?.task(at: rowIndex), let useCase = useCase else {
                fatalError("Couldn't find use case or data source for task list.")
            }
            destination.configure(useCase: useCase, task: task)
        }
        if segue.identifier == Self.showInstructionsSegueIdentifier,
           let destination = segue.destination as? TaskInstructionsViewController,
           let button = sender as? UIButton,
           let cell = button.superview?.superview?.superview as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            let rowIndex = indexPath.row
            guard let task = dataSource?.task(at: rowIndex) else {
                fatalError("Couldn't find data source for task list.")
            }
            destination.configure(with: task)
        }
        if segue.identifier == Self.showRecordingsSegueIdentifier,
           let destination = segue.destination as? RecordingListViewController,
           let cell = sender as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            let rowIndex = indexPath.row
            guard let task = dataSource?.task(at: rowIndex), let useCase = useCase else {
                fatalError("Couldn't find use case or data source for task list.")
            }
            destination.configure(useCase: useCase, task: task, delegate: self)
        }
    }
    
    @IBAction func unwindFromCamera(unwindSegue: UIStoryboardSegue) {
        dataSource?.sortTasks()
        tableView.reloadData()
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

// MARK: RecordingInteractionDelegate
extension TaskListViewController: RecordingInteractionDelegate {
    /**
     didUpdateRecording is called as part of RecordingInteractionDelegate, or whenever a recording update requires a UI update.
     
     Respond by updating the UI as follows.
     - delete: reload selected row and sort the task list.
     */
    func didUpdateRecording(_ recording: Recording?, shouldReloadRow: Bool) {
        
        // Get the indexPath for the recording. Use the currently selected indexPath if any, or the first row otherwise.
        // indexPath will remain nil if the tableView has no data.
        var indexPath: IndexPath?
        if let _ = recording {
            // indexPath = dataSource.index(for: recording.task)
        } else {
            indexPath = tableView.indexPathForSelectedRow
            if indexPath == nil && tableView.numberOfRows(inSection: 0) > 0 {
                indexPath = IndexPath(row: 0, section: 0)
            }
        }
        
        // Update the taskListViewController: make sure the row is visible and the content is up to date.
        if let indexPath = indexPath {
            if shouldReloadRow {
                tableView.reloadRows(at: [indexPath], with: .none)
                // If we deleted a the last recording for a task, sort the tasks again and reload the whole table
                if let task = dataSource?.task(at: indexPath.row), useCase?.recordingsCount(for: task) == 0 {
                    dataSource?.sortTasks()
                    tableView.reloadData()
                }
            }
            tableView.scrollToRow(at: indexPath, at: .none, animated: false)
        }
    }
    
}
