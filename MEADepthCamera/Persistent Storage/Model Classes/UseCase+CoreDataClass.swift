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
import OSLog

@objc(UseCase)
public class UseCase: NSManagedObject {
    
    private let logger = Logger.Category.fileIO.logger
    
    public override func awakeFromFetch() {
        super.awakeFromFetch()
        updateFolderURL()
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        date = Date()
        title = "New Use Case"
    }
    
    func updateFolderURL() {
        do {
            let docsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            guard let folderName = folderName else { return }
            folderURL = docsURL.appendingPathComponent(folderName, isDirectory: true)
        } catch {
            logger.error("Unable to locate Documents directory (\(String(describing: error)))")
            return
        }
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
    var folderName: String? {
        guard let title = title, let subjectID = subjectID, let date = date else { return nil }
        let dateText = Self.folderDateFormatter.string(from: date)
        let pathName = [title, subjectID, dateText].joined(separator: "_")
        return pathName
    }
    
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
    
    static let folderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        return formatter
    }()

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

