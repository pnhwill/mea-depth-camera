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

}

// MARK: JSON Decoder

/// A struct for decoding JSON with the following structure:
///
/// [
///     {
///         "Modality": "Video only",
///         "FileName": "SubjectID_NSM_BIGSMILE_YYYYMMDD_time_r",
///         "TaskName": "Big smile",
///         "Instructions": "Smile big. Repeat 3 times."
///     }
/// ]
///
/// Stores an array of decoded TaskProperties for later use in
/// creating or updating Task instances.

struct TasksJSON: Decodable {
    
    private(set) var taskPropertiesList = [TaskProperties]()
    
}


// MARK: Task Properties
struct TaskProperties: Decodable {
    /// A struct encapsulating the properties of a Task's JSON representation.
    
    // Codable
    
    private enum CodingKeys: String, CodingKey {
        case modality = "Modality"
        case fileName = "FileName"
        case name = "TaskName"
        case instructions = "Instructions"
    }
    
    let modality: String // "Video only"
    let fileName: String // "SubjectID_NSM_BIGSMILE_YYYYMMDD_time_r"
    let name: String // "Big smile"
    let instructions: String // "Smile big. Repeat 3 times."
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawModality = try? values.decode(String.self, forKey: .modality)
        let rawFileName = try? values.decode(String.self, forKey: .fileName)
        let rawName = try? values.decode(String.self, forKey: .name)
        let rawInstructions = try? values.decode(String.self, forKey: .instructions)
        
        // Ignore tasks with missing data.
        guard let modality = rawModality,
              let fileName = rawFileName,
              let name = rawName,
              let instructions = rawInstructions
        else {
            let values = "name = \(rawName?.description ?? "nil"), "
            + "modality = \(rawModality?.description ?? "nil"), "
            + "file name = \(rawFileName?.description ?? "nil"), "
            + "instructions = \(rawInstructions?.description ?? "nil")"

            let logger = Logger(subsystem: "com.mea-lab.MEADepthCamera", category: "parsing")
            logger.debug("Ignored: \(values)")
            throw TaskError.missingData
        }
        
        self.modality = modality
        self.fileName = fileName
        self.name = name
        self.instructions = instructions
    }
    
    // The keys must have the same name as the attributes of the Quake entity.
    var dictionaryValue: [String: Any] {
        [
            "modality": modality,
            "fileNameLabel": fileName,
            "name": name,
            "instructions": instructions
        ]
    }
    
}

// MARK: Task Error
enum TaskError: Error {
    case wrongDataFormat(error: Error)
    case missingData
    case batchInsertError
}

extension TaskError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .wrongDataFormat(let error):
            return NSLocalizedString("Could not digest the fetched data. \(error.localizedDescription)", comment: "")
        case .missingData:
            return NSLocalizedString("Found and will discard a task missing a valid modality, file name, name, or instructions.", comment: "")
        case .batchInsertError:
            return NSLocalizedString("Failed to execute a batch insert request.", comment: "")
        }
    }
}

extension TaskError: Identifiable {
    var id: String? {
        errorDescription
    }
}
