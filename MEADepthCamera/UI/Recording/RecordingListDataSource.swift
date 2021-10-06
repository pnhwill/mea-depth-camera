//
//  RecordingListDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit
import CoreData

class RecordingListDataSource: NSObject {

    private var useCase: UseCase
    private var task: Task
    private lazy var recordings: [Recording]? = {
        return useCase.recordings?.filter { ($0 as! Recording).task == task } as? [Recording]
    }()
    
    init(useCase: UseCase, task: Task) {
        self.useCase = useCase
        self.task = task
    }
    
    func sortRecordings() {
        // sort recordings by most recent
    }
    
    func recording(at section: Int) -> Recording? {
        return recordings?[section - 1]
    }
    
    func isRecordingProcessed(at section: Int) -> Bool? {
        let recording = recording(at: section)
        return recording?.isProcessed
    }
}

// MARK: UITableViewDataSource
extension RecordingListDataSource: UITableViewDataSource {
    static let taskNameCellIdentifier = "TaskNameCell"
    static let recordingListCellIdentifier = "RecordingListCell"
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + (recordings?.count ?? 0)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        switch section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.taskNameCellIdentifier, for: indexPath)
            cell.textLabel?.text = task.name
            return cell
        default:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.recordingListCellIdentifier, for: indexPath) as? RecordingListCell else {
                fatalError("###\(#function): Failed to dequeue a RecordingListCell. Check the cell reusable identifier in Main.storyboard.")
            }
            if let currentRecording = recording(at: indexPath.section), let folderText = currentRecording.folderURL?.lastPathComponent {
                cell.configure(folderName: folderText,
                               durationText: currentRecording.durationText(),
                               filesCountText: currentRecording.filesCountText())
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let currentRecording = recording(at: section) else { return nil }
        let sectionTitleText = currentRecording.isProcessed ? "Processed" : "Not Processed"
        return sectionTitleText
    }
    
    //TODO: delete recordings
    
}

// MARK: Duration Text Formatters
extension Recording {
    func durationText() -> String {
        return String(duration)
    }
    func filesCountText() -> String {
        return String(filesCount) + " Files"
    }
}
