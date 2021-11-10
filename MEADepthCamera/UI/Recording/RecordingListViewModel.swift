//
//  RecordingListViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/9/21.
//

import Foundation

class RecordingListViewModel {
    
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
    }
    
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
    }
    
    lazy var sectionsStore: ObservableModelStore<Section>? = {
        guard let sections = sections else { return nil }
        return ObservableModelStore(sections)
    }()
    lazy var itemsStore: ObservableModelStore<Item>? = {
        guard let items = items else { return nil }
        return ObservableModelStore(items)
    }()
    
    private let useCase: UseCase
    private let visionTrackingQueue = DispatchQueue(label: Bundle.main.reverseDNS(suffix: "visionTrackingQueue"), qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private lazy var recordings: [Recording]? = {
        return useCase.recordings?.allObjects as? [Recording]
    }()
    
    private var sections: [Section]? {
        guard let recordings = recordings else { return nil }
        let recordingsByTask = Dictionary(grouping: recordings, by: { $0.task! })
        return recordingsByTask.map { (task, recordings) in
            Section(title: task.name!,
                    id: task.id!,
                    recordings: recordings.map { $0.id! },
                    processedRecordings: recordings.filter { $0.isProcessed }.count)
        }
    }
    private var items: [Item]? {
        guard let recordings = recordings else { return nil }
        return recordings.map { item($0) }
    }
    
    init(useCase: UseCase) {
        self.useCase = useCase
    }
}

// MARK: Model Store Configuration
extension RecordingListViewModel {
    private func item(_ recording: Recording, processedFrames: Int? = nil) -> Item {
        return Item(name: recording.name!,
                    id: recording.id!,
                    isProcessedText: recording.isProcessedText,
                    totalFrames: Int(recording.totalFrames),
                    processedFrames: processedFrames)
    }
    
    /// Call each time a recording finishes being processed.
    private func reloadStores() {
        guard let sections = sections, let items = items else { return }
        sectionsStore?.merge(newModels: sections)
        itemsStore?.merge(newModels: items)
    }
    
    /// Call each time a new frame is processed.
    private func reconfigureItem(recording: Recording, processedFrames: Int) {
        let item = item(recording, processedFrames: processedFrames)
        itemsStore?.merge(newModels: [item])
    }
}
