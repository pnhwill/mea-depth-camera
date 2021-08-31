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
    
    private var dataSource: UITableViewDataSource?
    private var recordingEditAction: RecordingChangeAction?
    private var recordingAddAction: RecordingChangeAction?
    
    // Core Data
    var persistentContainer: PersistentContainer?
    
    func configure(with recording: Recording, isNew: Bool = false, addAction: RecordingChangeAction? = nil, editAction: RecordingChangeAction? = nil) {
        self.recording = recording
        self.isNew = isNew
        self.recordingAddAction = addAction
        self.recordingEditAction = editAction
        if isViewLoaded {
            setEditing(isNew, animated: false)
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let recording = recording {
            dataSource = RecordingDetailViewDataSource(recording: recording)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = navigationController,
            !navigationController.isToolbarHidden {
            navigationController.setToolbarHidden(true, animated: animated)
        }
    }
    
    
}
