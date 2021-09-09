//
//  RecordingListDataSource.swift
//  MEADepthCamera
//
//  Created by Will on 8/24/21.
//

import UIKit
import CoreData

class RecordingListDataSource: NSObject {

    typealias RecordingProcessedAction = (Int) -> Void
    typealias FrameProcessedAction = (Int, Int) -> Void
    typealias RecordingDeletedAction = () -> Void
    typealias RecordingChangedAction = () -> Void

    // MARK: Properties

    // State
    private var useCase: UseCase
    private var tasks: [Task]? {
        //return fetchedTasksResultsController.fetchedObjects
        return nil
    }
    private var recordings: [Recording]? {
        //return fetchedRecordingsResultsController.fetchedObjects
        return nil
    }
    //var selectedRecordings = [Recording]()
    var title: String = "Choose Task to Record"

    // Callbacks
    private var recordingDeletedAction: RecordingDeletedAction?
    private var recordingChangedAction: RecordingChangedAction?

    // Persistent storage

    private(set) lazy var persistentContainer: PersistentContainer = {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer
    }()


    // Task list
    //var tasksProvider: TaskProvider = .shared
    private var lastUpdated = Date.distantFuture.timeIntervalSince1970
    private var isLoading = false
    private var error: JSONError?
    private var hasError = false

    init(useCase: UseCase,
         recordingDeletedAction: @escaping RecordingDeletedAction,
         recordingChangedAction: @escaping RecordingChangedAction) {
        self.useCase = useCase
        self.recordingDeletedAction = recordingDeletedAction
        self.recordingChangedAction = recordingChangedAction
        super.init()
    }

    func task(at row: Int) -> Task? {
        return tasks?[row]
    }

    func recording(for task: Task) -> Recording? {
        return recordings?.first(where: { $0.task == task })
    }

    func fetchTasks() {
        isLoading = true
        do {
            //try tasksProvider.fetchTasks()
            lastUpdated = Date().timeIntervalSince1970
        } catch {
            self.error = error as? JSONError ?? .unexpectedError(error: error)
            self.hasError = true
        }
        isLoading = false
        recordingChangedAction?()
    }

}

// MARK: UITableViewDataSource

extension RecordingListDataSource: UITableViewDataSource {
    static let recordingListCellIdentifier = "RecordingListCell"

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.recordingListCellIdentifier, for: indexPath) as? RecordingListCell else {
            fatalError("###\(#function): Failed to dequeue a RecordingListCell. Check the cell reusable identifier in Main.storyboard.")
        }
        if let currentTask = task(at: indexPath.row), let nameText = currentTask.name {
            if let currentRecording = recording(for: currentTask), let folderText = currentRecording.folderURL?.lastPathComponent {
                // A recording has already been taken
                let durationText = currentRecording.durationText()
                cell.configure(taskName: nameText, durationText: durationText, folderName: folderText, filesCount: Int(currentRecording.filesCount), isProcessed: currentRecording.isProcessed)
                cell.backgroundColor = .systemGreen
                cell.accessoryType = .detailButton
            } else {
                // A recording has not yet been taken
                cell.configure(taskName: nameText, durationText: nil, folderName: nil, filesCount: nil, isProcessed: nil)
                cell.backgroundColor = .secondarySystemBackground
                cell.accessoryType = .none
            }
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

// MARK: Selection Interface

//extension RecordingListDataSource {
//
//    func isSelected(at row: Int) -> Bool {
//        guard let recording = recording(at: row) else { return false }
//        return selectedRecordings.contains(recording)
//    }
//
//    func selectRecording(at row: Int) {
//        guard let recording = recording(at: row) else { return }
//        if isSelected(at: row) {
//            selectedRecordings.remove(at: selectedIndex(for: row))
//        } else {
//            selectedRecordings.append(recording)
//        }
//    }
//
//    func selectedIndex(for index: Int) -> Int {
//        guard let recording = recording(at: index),
//              let selectedIndex = selectedRecordings.firstIndex(where: { $0.id == recording.id }) else {
//            fatalError("Couldn't retrieve index in source array")
//        }
//        return selectedIndex
//    }
//
//    func index(for selectedIndex: Int) -> Int {
//        let recording = selectedRecordings[selectedIndex]
//        guard let index = recordings?.firstIndex(where: { $0.id == recording.id }) else {
//            fatalError("Couldn't retrieve index in source array")
//        }
//        return index
//    }
//
//    func startProcessing() {
//        guard !selectedRecordings.isEmpty else { return }
//    }
//
//}



// MARK: UISearchResultsUpdating

//extension RecordingListDataSource: UISearchResultsUpdating {
//    func updateSearchResults(for searchController: UISearchController) {
//        let predicate: NSPredicate
//        if let userInput = searchController.searchBar.text, !userInput.isEmpty {
//            predicate = NSPredicate(format: "title CONTAINS[cd] %@", userInput)
//        } else {
//            predicate = NSPredicate(value: true)
//        }
//
//        fetchedResultsController.fetchRequest.predicate = predicate
//        do {
//            try fetchedResultsController.performFetch()
//        } catch {
//            fatalError("###\(#function): Failed to performFetch: \(error)")
//        }
//
//        recordingChangedAction?()
//    }
//}

// MARK: Persistent Storage Interface

//extension RecordingListDataSource {
//
//    func update(_ recording: Recording, at row: Int, completion: (Bool) -> Void) {
//        if let context = recording.managedObjectContext {
//            persistentContainer.saveContext(backgroundContext: context)
//            context.refresh(recording, mergeChanges: true)
//            completion(true)
//        } else {
//            completion(false)
//        }
//    }
//
//    func delete(at row: Int, completion: (Bool) -> Void) {
//        if let recording = self.recording(at: row), let context = recording.managedObjectContext {
//            context.delete(recording)
//            persistentContainer.saveContext(backgroundContext: context)
//            context.refresh(recording, mergeChanges: true)
//            completion(true)
//        } else {
//            completion(false)
//        }
//    }
//
//    func add(_ recording: Recording, completion: (Bool) -> Void) {
//        if let context = recording.managedObjectContext {
//            persistentContainer.saveContext(backgroundContext: context)
//            context.refresh(recording, mergeChanges: true)
//            completion(true)
//        } else {
//            completion(false)
//        }
//    }
//}
