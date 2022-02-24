//
//  Task+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 8/12/21.
//
//

import Foundation
import CoreData
import OSLog

@objc(Task)
public class Task: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        name = "New Task"
        isDefaultString = isDefault ? SectionName.standard.rawValue : SectionName.custom.rawValue
    }
}

extension Task: Searchable {
    static var searchKeys: [String] = [
        Schema.Task.name.rawValue,
        Schema.Task.fileNameLabel.rawValue,
        Schema.Task.instructions.rawValue,
    ]
}

extension Task {
    enum SectionName: String {
        case all = ""
        case custom = "Custom Tasks"
        case standard = "Default Tasks"
    }
}

extension Task: ListObject {}

// MARK: Text Formatters
extension Task {
    func recordingsCountText(for useCase: UseCase) -> String {
        let recordingsCount = useCase.recordingsCount(for: self)
        switch recordingsCount {
        case 1:
            return String(recordingsCount) + " recording"
        default:
            return String(recordingsCount) + " recordings"
        }
    }
    
    func isComplete(for useCase: UseCase) -> Bool {
        return useCase.recordingsCount(for: self) > 0
    }
}


