//
//  UseCase+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 8/11/21.
//
//

import Foundation
import CoreData
import UIKit

@objc(UseCase)
public class UseCase: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        date = Date()
        title = "New Use Case"
    }
}

extension UseCase: Searchable {
    static var searchKeys: [String] = [
        Schema.UseCase.title.rawValue,
        Schema.UseCase.subjectID.rawValue,
        Schema.UseCase.experimentTitle.rawValue,
    ]
}

extension UseCase {
    enum SectionName: String {
        case all = ""
    }
}

extension UseCase: ListObject {}

// MARK: Convenience Accessors

extension UseCase {
    var tasksCount: Int {
        Int(experiment!.tasksCount)
    }
    
    var completedTasks: Int {
        let tasks = experiment!.tasks as! Set<Task>
        return tasks.reduce(0) { $0 + ($1.isComplete(for: self) ? 1 : 0) }
    }
    
    func recordingsCount(for task: Task) -> Int {
        let recordings = recordings as! Set<Recording>
        return recordings.reduce(0) { $0 + ($1.task == task ? 1 : 0) }
    }
}

// MARK: Text Formatters
extension UseCase {
    var subjectIDText: String {
        let subjectID = subjectID ?? "?"
        return "Subject ID: ".appending(subjectID)
    }
    
    func recordingsCountText() -> String {
        switch recordingsCount {
        case 1:
            return String(recordingsCount) + " Recording"
        default:
            return String(recordingsCount) + " Recordings"
        }
    }
}

// MARK: Date/Time Formatters
extension UseCase {

    static let pastDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    static let todayDateFormatter: DateFormatter = {
        let format = NSLocalizedString("'Today at '%@", comment: "format string for dates occurring today")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = String(format: format, "hh:mm a")
        return dateFormatter
    }()

    func dateTimeText() -> String? {
        guard let date = date else { return nil }
        let isInToday = Locale.current.calendar.isDateInToday(date)
        if isInToday {
            return Self.todayDateFormatter.string(from: date)
        } else {
            return Self.pastDateFormatter.string(from: date)
        }
    }
}

