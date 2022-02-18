//
//  TaskStartViewModel.swift
//  MEADepthCamera
//
//  Created by Will on 11/4/21.
//

import Foundation
import UIKit

/// The view model for TaskStartViewController.
class TaskStartViewModel {
    
    // MARK: Section
    struct Section: Identifiable {
        enum Identifier: Int, CaseIterable {
            case info
            case recordings
        }
        
        var id: Identifier
        var items: [DetailItem.ID]
    }
    
    // MARK: Info Items
    struct InfoItems {
        enum ItemType: Int, CaseIterable {
            case name
            case fileName
            case modality
            case instructions
            
            var id: UUID {
                InfoItems.identifiers[self.rawValue]
            }
            
            var cellImage: UIImage? {
                switch self {
                case .name:
                    return nil
                case .fileName:
                    return UIImage(systemName: "folder")
                case .modality:
                    return UIImage(systemName: "video.and.waveform")
                case .instructions:
                    return UIImage(systemName: "info")
                }
            }
            
            func displayText(for task: Task) -> String? {
                switch self {
                case .name:
                    return task.name
                case .fileName:
                    return task.fileNameLabel
                case .modality:
                    return task.modality
                case .instructions:
                    return task.instructions
                }
            }
        }
        
        static let identifiers: [UUID] = {
            return ItemType.allCases.map { _ in UUID() }
        }()
    }
    
    // MARK: Recording Item
    struct RecordingItem {
        let id: UUID
        let name: String
        let isProcessedText: String
        let durationText: String
        let filesCountText: String
        
        init?(_ recording: Recording) {
            guard let id = recording.id else { return nil }
            self.id = id
            self.name = recording.name ?? "?"
            self.isProcessedText = recording.isProcessedText
            self.durationText = recording.durationText
            self.filesCountText = recording.filesCountText
        }
        
        var listItem: DetailItem {
            DetailItem(id: id, title: name, bodyText: [isProcessedText, durationText, filesCountText])
        }
    }
    
    // MARK: Data Stores
    lazy var sectionsStore: AnyModelStore<Section>? = {
        let infoSection = Section(id: .info, items: infoItemIds)
        let recordingsSection = Section(id: .recordings, items: recordingItemIds ?? [])
        return AnyModelStore([infoSection, recordingsSection])
    }()
    lazy var itemsStore: AnyModelStore<DetailItem>? = {
        let items = [infoItems, recordingItems].compactMap { $0 }.flatMap { $0 }
        return AnyModelStore(items)
    }()
    
    private var useCase: UseCase
    private var task: Task
    private lazy var recordings: [Recording]? = {
        let recordings = useCase.recordings?.filter { ($0 as! Recording).task == task } as? [Recording]
        return recordings
    }()
    private var sortedRecordings: [Recording]? {
        recordings?.sorted { $0.name! < $1.name! }
    }
    private var infoItems: [DetailItem] {
        InfoItems.ItemType.allCases.map { DetailItem(id: $0.id, title: $0.displayText(for: task) ?? "?", image: $0.cellImage) }
    }
    private var recordingItems: [DetailItem]? {
        sortedRecordings?.compactMap { RecordingItem($0)?.listItem }
    }
    private var infoItemIds: [UUID] {
        InfoItems.ItemType.allCases.map { $0.id }
    }
    private var recordingItemIds: [UUID]? {
        sortedRecordings?.compactMap { $0.id }
    }
    
    init(task: Task, useCase: UseCase) {
        self.useCase = useCase
        self.task = task
    }
}

