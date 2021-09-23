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
    
    static let mainStoryboardName = "Main"
    static let showCameraSegueIdentifier = "ShowCameraSegue"
    static let unwindFromCameraSegueIdentifier = "UnwindFromCameraSegue"
    static let showRecordingsSegueIdentifier = "ShowRecordingListSegue"
    static let recordingsViewControllerIdentifier = "RecordingListViewController"
    
    private var dataSource: TaskListDataSource?
    
    // State
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
            destination.configure(useCase: useCase!, task: (dataSource?.task(at: rowIndex))!)
        }
    }
    
    @IBAction func unwindFromCamera(unwindSegue: UIStoryboardSegue) {
        tableView.reloadData()
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = dataSource
        navigationItem.title = dataSource?.navigationTitle
    }
    
    private func refreshUseCaseView() {
        let titleText = [useCase?.experiment?.title, useCase?.title].compactMap { $0 }.joined(separator: ": ")
        useCaseView.configure(title: titleText, subjectIDText: useCase?.subjectID)
    }
}
