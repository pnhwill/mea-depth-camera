//
//  RecordingListDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit
import CoreData

class RecordingListDataSource: NSObject {
    
    typealias RecordingDeletedAction = () -> Void
    
    var navigationTitle: String = "Review Recordings"
    
    lazy var dataProvider: RecordingProvider = {
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        let provider = RecordingProvider(with: container)
        return provider
    }()
    
    private var useCase: UseCase
    private var task: Task
    private lazy var recordings: [Recording]? = {
        let recordings = useCase.recordings?.filter { ($0 as! Recording).task == task } as? [Recording]
        return recordings
    }()
    
    private var recordingDeletedAction: RecordingDeletedAction?
    
    init(useCase: UseCase, task: Task, recordingDeletedAction: @escaping RecordingDeletedAction) {
        self.useCase = useCase
        self.task = task
        self.recordingDeletedAction = recordingDeletedAction
        super.init()
        sortRecordings()
    }
    
    func sortRecordings() {
        // sort recordings by most recent (abusing the fact that they are currently always named by datetime)
        recordings?.sort { $0.name! < $1.name! }
    }
    
    func delete(at section: Int, completion: @escaping (Bool) -> Void) {
        if let recording = self.recording(at: section) {
            dataProvider.delete(recording) { success in
                if success {
                    let index = self.index(for: section)
                    self.recordings?.remove(at: index)
                }
                completion(success)
            }
        } else {
            completion(false)
        }
    }
    
    func recording(at section: Int) -> Recording? {
        return recordings?[section - 1]
    }
    
    func isRecordingProcessed(at section: Int) -> Bool? {
        let recording = recording(at: section)
        return recording?.isProcessed
    }
    
    func index(for section: Int) -> Int {
        // Below implementation is only needed once dynamic sorting is added.
//        let filteredReminder = filteredReminders[filteredIndex]
//        guard let index = reminders.firstIndex(where: { $0.id == filteredReminder.id }) else {
//            fatalError("Couldn't retrieve index in source array")
//        }
//        return index
        return section - 1
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
            if let currentRecording = recording(at: section), let folderText = currentRecording.folderURL?.lastPathComponent {
                cell.configure(folderName: folderText,
                               durationText: currentRecording.durationText,
                               filesCountText: currentRecording.filesCountText)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return nil
        default:
            guard let currentRecording = recording(at: section) else { return nil }
            let sectionTitleText = currentRecording.isProcessed ? "Processed" : "Not Processed"
            return sectionTitleText
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {
            return
        }
        delete(at: indexPath.section) { success in
            if success {
                DispatchQueue.main.async {
                    tableView.reloadData()
                    self.recordingDeletedAction?()
                }
            }
        }
    }
    
}

