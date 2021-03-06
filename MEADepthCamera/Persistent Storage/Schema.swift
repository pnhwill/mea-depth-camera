//
//  Schema.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData

/// Relevant entities and attributes from the Core Data model.
///
/// Use these to check whether a persistent history change is relevant to the current view.
enum Schema {
    
    enum Shared: String {
        case id
    }
    
    enum UseCase: String {
        case title, date, subjectID, experimentTitle
    }
    
    enum Recording: String {
        case name
    }
    
    enum Experiment: String {
        case title
    }
    
    enum Task: String {
        case name, fileNameLabel, instructions, isDefaultString
    }
}
