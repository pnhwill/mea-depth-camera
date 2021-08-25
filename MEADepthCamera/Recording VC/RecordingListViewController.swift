//
//  RecordingListViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit

class RecordingListViewController: UITableViewController {
    
    // MARK: Properties
    
    static let showDetailSegueIdentifier = "ShowRecordingDetailSegue"
    static let showCameraSegueIdentifier = "ShowCameraSegue"
    
    private var recordingListDataSource: RecordingListDataSource?
    
    // State
    private var useCase: UseCase!
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Self.showDetailSegueIdentifier,
           let destination = segue.destination as? RecordingDetailViewController,
           let cell = sender as? UITableViewCell,
           let indexPath = tableView.indexPath(for: cell) {
            let rowIndex = indexPath.row
            guard let recording = recordingListDataSource?.recording(at: rowIndex) else {
                fatalError("Couldn't find data source for recording list.")
            }
            destination.configure(with: recording, editAction: { recording in
                self.recordingListDataSource?.update(recording, at: rowIndex) { success in
                    if success {
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    } else {
                        DispatchQueue.main.async {
                            let alertTitle = NSLocalizedString("Can't Update Recording", comment: "error updating recording title")
                            let alertMessage = NSLocalizedString("An error occured while attempting to update the recording.", comment: "error updating recording message")
                            let actionTitle = NSLocalizedString("OK", comment: "ok action title")
                            let actions = [UIAlertAction(title: actionTitle, style: .default, handler: { _ in
                                self.dismiss(animated: true, completion: nil)
                            })]
                            self.alert(title: alertTitle, message: alertMessage, actions: actions)
                        }
                    }
                }
            })
        }
        //if segue.identifier == Self.showCameraSegueIdentifier
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordingListDataSource = RecordingListDataSource(useCase: useCase,
                                                          recordingDeletedAction: {
                                                            // handle recording deleted
                                                          }, recordingChangedAction: {
                                                            DispatchQueue.main.async {
                                                                self.tableView.reloadData()
                                                            }
                                                          })
        tableView.dataSource = recordingListDataSource
        navigationItem.title = useCase.title
        // Search bar controller
        //        let searchController = UISearchController(searchResultsController: nil)
        //        searchController.searchResultsUpdater = useCaseListDataSource
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
    
}
