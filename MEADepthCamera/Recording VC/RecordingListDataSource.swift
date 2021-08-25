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
    typealias RecordingChangedAction = () -> Void
    
    // MARK: Properties
    
    // State
    private var useCase: UseCase
    private var filteredRecordings: [Recording]?
    
    // Callbacks
    private var recordingDeletedAction: RecordingDeletedAction?
    private var recordingChangedAction: RecordingChangedAction?
    
    // Persistent storage
    
    private(set) lazy var persistentContainer: PersistentContainer = {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer
    }()
    
    private lazy var fetchedResultsController: NSFetchedResultsController<Recording> = {
        let fetchRequest: NSFetchRequest<Recording> = Recording.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Recording.Name.name, ascending: true)]
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: persistentContainer.viewContext,
                                                    sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        do {
            try controller.performFetch()
        } catch {
            fatalError("###\(#function): Failed to performFetch: \(error)")
        }
        return controller
    }()
    
    init(useCase: UseCase, recordingDeletedAction: @escaping RecordingDeletedAction, recordingChangedAction: @escaping RecordingChangedAction) {
        self.useCase = useCase
        self.recordingDeletedAction = recordingDeletedAction
        self.recordingChangedAction = recordingChangedAction
        super.init()
    }
    
    // MARK: Persistent Storage Interface
    
    func update(_ recording: Recording, at row: Int, completion: (Bool) -> Void) {
        if let context = recording.managedObjectContext {
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(recording, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func delete(at row: Int, completion: (Bool) -> Void) {
        if let recording = self.recording(at: row), let context = recording.managedObjectContext {
            context.delete(recording)
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(recording, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func add(_ recording: Recording, completion: (Bool) -> Void) {
        if let context = recording.managedObjectContext {
            persistentContainer.saveContext(backgroundContext: context)
            context.refresh(recording, mergeChanges: true)
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func recording(at row: Int) -> Recording? {
        return filteredRecordings?[row]
    }
    
    
}

// MARK: UITableViewDataSource

extension RecordingListDataSource: UITableViewDataSource {
    static let recordingListCellIdentifier = "RecordingListCell"
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.recordingListCellIdentifier, for: indexPath) as? RecordingListCell else {
            fatalError("###\(#function): Failed to dequeue a RecordingListCell. Check the cell reusable identifier in Main.storyboard.")
        }
        if let currentRecording = recording(at: indexPath.row) {
            let durationText = currentRecording.durationText()
            cell.configure(name: currentRecording.name!, durationText: durationText, taskText: "task", filesCount: Int(currentRecording.filesCount), isProcessed: currentRecording.isProcessed)
        }
        return cell
    }
}

// MARK: Duration Text Formatters
extension Recording {
    
    func durationText() -> String {
        return String(duration)
    }
}

// MARK: NSFetchedResultsControllerDelegate

extension RecordingListDataSource: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        recordingChangedAction?()
    }
}

// MARK: UISearchResultsUpdating

//extension RecordingListDataSource: UISearchResultsUpdating {
//
//}
