//
//  Schema.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//
/*
Abstract:
Select entities and attributes from the Core Data model. Use these to check whether a persistent history change is relevant to the current view.
*/

import CoreData

/**
 Relevant entities and attributes in the Core Data schema.
 */
struct Schema {
    
    enum UseCase: String {
        case title, date
    }
    
    enum Recording: String {
        case name
    }
    
    enum Experiment: String {
        case title
    }
    
    enum Task: String {
        case name
    }
}
