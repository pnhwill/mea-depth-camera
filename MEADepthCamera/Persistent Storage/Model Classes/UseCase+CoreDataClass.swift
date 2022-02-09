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

    static let timeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()

    static let pastDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    static let todayDateFormatter: DateFormatter = {
        let format = NSLocalizedString("'Today at '%@", comment: "format string for dates occurring today")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = String(format: format, "hh:mm a")
        return dateFormatter
    }()

    func dateTimeText(for filter: UseCaseListViewModel.Filter) -> String? {
        guard let date = date else { return nil }
        let isInToday = Locale.current.calendar.isDateInToday(date)
        switch filter {
        case .today:
            return Self.timeFormatter.string(from: date)
        case .past:
            return Self.pastDateFormatter.string(from: date)
        case .all:
            if isInToday {
                return Self.todayDateFormatter.string(from: date)
            } else {
                return Self.pastDateFormatter.string(from: date)
            }
        }
    }
}

