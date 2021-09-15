//
//  Experiment+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
//

import Foundation
import CoreData
import OSLog

@objc(Experiment)
public class Experiment: NSManagedObject {
    
    /// Updates an Experiment instance with the values from an ExperimentProperties.
    func update(from experimentProperties: ExperimentProperties) throws {
        let dictionary = experimentProperties.dictionaryValue
        guard let newTitle = dictionary["title"] as? String,
              //let newTasks = dictionary["tasks"] as? [String],
              let newID = dictionary["id"] as? UUID
        else {
            throw JSONError.missingData
        }
        
        title = newTitle
        id = newID
    }
    
}

// MARK: JSON Decoder

/// A struct for decoding JSON with the following structure:
///
/// [
///     {
///         "title": "Parkinson's - Full",
///         "tasks": [
///             {
///                 "name": "RST_REST1"
///             }
///             ...
///         ]
///     }
/// ]
///
/// Stores an array of decoded ExperimentProperties for later use in
/// creating or updating Experiment instances.

struct ExperimentsJSON: Decodable {
    
    private(set) var propertiesList = [ExperimentProperties]()
    
    init(from decoder: Decoder) throws {
        var rootContainer = try decoder.unkeyedContainer()
        
        while !rootContainer.isAtEnd {
            if let properties = try? rootContainer.decode(ExperimentProperties.self) {
                propertiesList.append(properties)
            }
        }
    }
}

// MARK: Experiment Properties
struct ExperimentProperties: Decodable {
    /// A struct encapsulating the properties of an Experiment's JSON representation.
    
    // Codable
    
    private enum CodingKeys: String, CodingKey {
        case title
        case tasks
    }
    private enum TasksCodingKeys: String, CodingKey {
        case name
    }
    
    let title: String
    let tasks: [String]
    let id: UUID
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        var tasksContainer = try values.nestedUnkeyedContainer(forKey: .tasks)
        let rawTitle = try? values.decode(String.self, forKey: .title)
        var rawTasks = [String]()
        while !tasksContainer.isAtEnd {
            let taskNameContainer = try tasksContainer.nestedContainer(keyedBy: TasksCodingKeys.self)
            if let task = try? taskNameContainer.decode(String.self, forKey: .name) {
                rawTasks.append(task)
            }
        }
        
        // Ignore experiments with missing data.
        guard let title = rawTitle, !rawTasks.isEmpty
        else {
            let values = "title = \(rawTitle?.description ?? "nil")"
            let logger = Logger(subsystem: "com.mea-lab.MEADepthCamera", category: "parsing")
            logger.debug("Ignored experiment: \(values)")
            throw JSONError.missingData
        }
        let tasks = rawTasks
        
        self.title = title
        self.tasks = tasks
        self.id = UUID()
    }
    
    // The keys must have the same name as the attributes of the Experiment entity.
    var dictionaryValue: [String: Any] {
        [
            "title": title,
            "tasks": tasks,
            "id": id
        ]
    }
    
}
