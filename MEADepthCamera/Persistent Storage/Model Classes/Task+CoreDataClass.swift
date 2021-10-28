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
    
    /// Updates a Task instance with the values from a TaskProperties.
    func update(from taskProperties: TaskProperties) throws {
        let dictionary = taskProperties.dictionaryValue
        guard let newModality = dictionary["modality"] as? String,
              let newFileNameLabel = dictionary["fileNameLabel"] as? String,
              let newName = dictionary["name"] as? String,
              let newInstructions = dictionary["instructions"] as? String,
              let newID = dictionary["id"] as? UUID
        else {
            throw JSONError.missingData
        }
        
        modality = newModality
        fileNameLabel = newFileNameLabel
        name = newName
        instructions = newInstructions
        id = newID
    }
    
}

extension Task: ModelObject {

}

// MARK: Text Formatters
extension Task {
    func recordingsCountText(for useCase: UseCase) -> String {
        let recordingsCount = useCase.recordingsCount(for: self)
        switch recordingsCount {
        case 1:
            return String(recordingsCount) + " Recording"
        default:
            return String(recordingsCount) + " Recordings"
        }
    }
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
    
    init(from decoder: Decoder) throws {
        var rootContainer = try decoder.unkeyedContainer()
        
        while !rootContainer.isAtEnd {
            if let properties = try? rootContainer.decode(TaskProperties.self) {
                taskPropertiesList.append(properties)
            }
        }
    }
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
    let id: UUID
    
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
            throw JSONError.missingData
        }
        
        self.modality = modality
        self.fileName = fileName
        self.name = name
        self.instructions = instructions
        self.id = UUID()
    }
    
    // The keys must have the same name as the attributes of the Task entity.
    var dictionaryValue: [String: Any] {
        [
            "modality": modality,
            "fileNameLabel": fileName,
            "name": name,
            "instructions": instructions,
            "id": id
        ]
    }
    
}


