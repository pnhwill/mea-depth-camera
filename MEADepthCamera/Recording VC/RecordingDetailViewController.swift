//
//  RecordingDetailViewController.swift
//  MEADepthCamera
//
//  Created by Will on 8/23/21.
//

import UIKit

class RecordingDetailViewController: UIViewController {
    
    typealias RecordingChangeAction = (Recording) -> Void
    
    // Current recording
    private var recording: Recording?
    private var isNew = false
    
    private var dataSource: UITableViewDataSource?
    private var useCaseEditAction: RecordingChangeAction?
    private var useCaseAddAction: RecordingChangeAction?
    
    // Core Data
    var persistentContainer: PersistentContainer?
    
    func configure(with recording: Recording, isNew: Bool = false, addAction: RecordingChangeAction? = nil, editAction: RecordingChangeAction? = nil) {
        self.recording = recording
        self.isNew = isNew
        self.useCaseAddAction = addAction
        self.useCaseEditAction = editAction
        if isViewLoaded {
            setEditing(isNew, animated: false)
        }
    }
    
    // MARK: Life Cycle
    
    
    
    
}
