//
//  ProcessingListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/9/21.
//

import Foundation

/// The view model for the ProcessingListViewController.
class ProcessingListViewModel {
    
    typealias ProcessingCompleteAction = () -> Void
    
    // MARK: Section
    struct Section: Identifiable {
        let title: String
        let id: UUID
        let recordings: [UUID]
        var processedRecordings: Int = 0
        
        var totalRecordings: Int {
            recordings.count
        }
        var processedRecordingsText: String {
            return "\(processedRecordings)/\(totalRecordings) recordings processed."
        }
        
        init(task: Task, recordings: [Recording]) {
            self.title = task.name!
            self.id = task.id!
            self.recordings = recordings.map { $0.id! }
            self.processedRecordings = recordings.filter { $0.isProcessed }.count
        }
    }
    
    // MARK: Item
    struct Item: Identifiable, Hashable {
        let name: String
        let id: UUID
        var isProcessedText: String
        var totalFrames: Int
        var processedFrames: Int? = 0
        
        var progress: Float? {
            guard let processedFrames = processedFrames else { return nil }
            return Float(processedFrames) / Float(totalFrames)
        }
        var frameCounterText: String? {
            guard let processedFrames = processedFrames else { return nil }
            return "Frame: \(processedFrames)/\(totalFrames)"
        }
        
        init(_ recording: Recording, processedFrames: Int? = nil) {
            self.name = recording.name!
            self.id = recording.id!
            self.isProcessedText = recording.isProcessedText
            self.totalFrames = Int(recording.totalFrames)
            self.processedFrames = processedFrames
        }
    }
    
    // MARK: Model Stores
    lazy var sectionsStore: ObservableModelStore<Section>? = {
        guard let sections = sections else { return nil }
        return ObservableModelStore(sections)
    }()
    lazy var itemsStore: ObservableModelStore<Item>? = {
        guard let items = items else { return nil }
        return ObservableModelStore(items)
    }()
    
    private let useCase: UseCase
    
    private var recordings: [Recording]? {
        useCase.recordings?.allObjects as? [Recording]
    }
    
    private var sections: [Section]? {
        guard let recordings = recordings else { return nil }
        let recordingsByTask = Dictionary(grouping: recordings, by: { $0.task! })
        return recordingsByTask.map { Section(task: $0, recordings: $1) }
    }
    private var items: [Item]? {
        recordings?.compactMap { Item($0) }
    }
    
    // Post-Processing
    private var faceLandmarksPipeline: FaceLandmarksPipeline?
    private var processingCompleteAction: ProcessingCompleteAction?
    private var cancelRequested = false
    
    init(useCase: UseCase, processingCompleteAction: ProcessingCompleteAction? = nil) {
        self.useCase = useCase
        self.processingCompleteAction = processingCompleteAction
    }
    
    func startProcessing() throws {
        defer {
            processingCompleteAction?()
        }
        guard let recordings = recordings else { return }
        for recording in recordings {
            if cancelRequested {
                break
            }
            try startTracking(recording)
        }
    }
    
    func cancelProcessing() {
        cancelRequested = true
        faceLandmarksPipeline?.cancelTracking()
    }
}

// MARK: Model Store Configuration
extension ProcessingListViewModel {
    /// Call each time a recording finishes being processed.
    private func reloadStores() {
        guard let sections = sections, let items = items else { return }
        sectionsStore?.merge(newModels: sections)
        itemsStore?.merge(newModels: items)
    }
    /// Call each time a new frame is processed.
    private func reconfigureItem(recording: Recording, processedFrames: Int) {
        let item = Item(recording, processedFrames: processedFrames)
        itemsStore?.merge(newModels: [item])
    }
}

// MARK: Face Landmarks Processing
extension ProcessingListViewModel {
    private func startTracking(_ recording: Recording) throws {
        guard !recording.isProcessed, let faceLandmarksPipeline = FaceLandmarksPipeline(recording: recording) else {
            return
        }
        self.faceLandmarksPipeline = faceLandmarksPipeline
        faceLandmarksPipeline.delegate = self
        try faceLandmarksPipeline.startTracking()
    }
}

// MARK: FaceLandmarksPipelineDelegate
extension ProcessingListViewModel: FaceLandmarksPipelineDelegate {
    func displayFrameCounter(_ frame: Int) {
        guard let recording = faceLandmarksPipeline?.recording else { return }
        reconfigureItem(recording: recording, processedFrames: frame)
        NotificationCenter.default.post(name: .recordingDidChange, object: self, userInfo: [NotificationKeys.recordingId: recording.id!])
    }
    
    func didFinishTracking(success: Bool) {
        guard let recording = faceLandmarksPipeline?.recording else { return }
        let context = recording.managedObjectContext
        let container = AppDelegate.shared.coreDataStack.persistentContainer
        if success {
            recording.isProcessed = true
            container.saveContext(backgroundContext: context, with: .updateRecording)
        } else {
            context?.rollback()
        }
        reloadStores()
    }
}
