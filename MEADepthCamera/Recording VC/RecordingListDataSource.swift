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
    private var recordings: [Recording]? {
        return fetchedResultsController.fetchedObjects
    }
    var selectedRecordings = [Recording]()
    
    // Callbacks
    private var recordingDeletedAction: RecordingDeletedAction?
    private var recordingChangedAction: RecordingChangedAction?
    private var recordingProcessedAction: RecordingProcessedAction?
    private var frameProcessedAction: FrameProcessedAction?
    
    // Persistent storage
    
    private(set) lazy var persistentContainer: PersistentContainer = {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        return appDelegate!.persistentContainer
    }()
    
    private lazy var fetchedResultsController: NSFetchedResultsController<Recording> = {
        let fetchRequest: NSFetchRequest<Recording> = Recording.fetchRequest()
        let predicate = NSPredicate(format: "useCase.id.uuidString == %@", useCase.id!.uuidString)
        fetchRequest.predicate = predicate
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
    
    init(useCase: UseCase,
         processorSettings: ProcessorSettings,
         recordingDeletedAction: @escaping RecordingDeletedAction,
         recordingChangedAction: @escaping RecordingChangedAction,
         recordingProcessedAction: @escaping RecordingProcessedAction,
         frameProcessedAction: @escaping FrameProcessedAction) {
        self.useCase = useCase
        self.recordingDeletedAction = recordingDeletedAction
        self.recordingChangedAction = recordingChangedAction
        super.init()
    }
    
    func recording(at row: Int) -> Recording? {
        return recordings?[row]
    }
    
    func isSelected(at row: Int) -> Bool {
        guard let recording = recording(at: row) else { return false }
        return selectedRecordings.contains(recording)
    }
    
    func selectRecording(at row: Int) {
        guard let recording = recording(at: row) else { return }
        if isSelected(at: row) {
            selectedRecordings.remove(at: selectedIndex(for: row))
        } else {
            selectedRecordings.append(recording)
        }
    }
    
    func selectedIndex(for index: Int) -> Int {
        guard let recording = recording(at: index),
              let selectedIndex = selectedRecordings.firstIndex(where: { $0.id == recording.id }) else {
            fatalError("Couldn't retrieve index in source array")
        }
        return selectedIndex
    }
    
    func index(for selectedIndex: Int) -> Int {
        let recording = selectedRecordings[selectedIndex]
        guard let index = recordings?.firstIndex(where: { $0.id == recording.id }) else {
            fatalError("Couldn't retrieve index in source array")
        }
        return index
    }
    
    func startProcessing() {
        guard !selectedRecordings.isEmpty else { return }
        
        
        
    }
    
}

// MARK: UITableViewDataSource

extension RecordingListDataSource: UITableViewDataSource {
    static let recordingListCellIdentifier = "RecordingListCell"
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordings?.count ?? 0
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
