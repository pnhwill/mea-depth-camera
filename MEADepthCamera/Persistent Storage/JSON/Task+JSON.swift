//
//  Task+JSON.swift
//  MEADepthCamera
//
//  Created by Will on 2/16/22.
//

import Foundation
import OSLog

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

/// A struct encapsulating the properties of a Task's JSON representation.
struct TaskProperties: Decodable {
    
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
    let isDefault: Bool
    
    private let logger = Logger.Category.json.logger
    
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
            logger.error("Ignored task with missing data: \(values)")
            throw JSONError.missingData
        }
        
        self.modality = modality
        self.fileName = fileName
        self.name = name
        self.instructions = instructions
        self.id = UUID()
        self.isDefault = true
    }
    
    /// The keys must have the same name as the attributes of the Task entity.
    var dictionaryValue: [String: Any] {
        [
            "modality": modality,
            "fileNameLabel": fileName,
            "name": name,
            "instructions": instructions,
            "id": id,
            "isDefault": isDefault
        ]
    }
}

extension Task {
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
