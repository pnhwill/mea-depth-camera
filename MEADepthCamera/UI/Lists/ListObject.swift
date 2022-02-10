//
//  ListObject.swift
//  MEADepthCamera
//
//  Created by Will on 2/7/22.
//

import CoreData

// MARK: Searchable

protocol Searchable {
    static var searchPredicate: String { get }
}

protocol ListObject: NSManagedObject, Searchable, Identifiable where ID == UUID? {
    
}
