//
//  ModelObject.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/15/21.
//

import UIKit
import CoreData

protocol ModelObject: AnyObject, Identifiable where ID == UUID? {
    
    static func generateListContentConfiguration() -> ListContentConfiguration
    
}

struct Section: Identifiable {
    enum Identifier: Int, CaseIterable {
        case header
        case list
        
    }
    
    var id: Identifier
    var items: [Item.ID]?
}

struct Item: Identifiable, Hashable {
    var id: UUID?
    var object: NSManagedObject
    
    init<T>(object: T) where T: NSManagedObject, T: ModelObject {
        self.object = object
        self.id = object.id
    }
}
