//
//  ListObject.swift
//  MEADepthCamera
//
//  Created by Will on 2/7/22.
//

import CoreData

// MARK: Searchable

protocol Searchable {
    static var searchKeys: [String] { get }
}

extension Searchable {
    static var searchFormat: String {
        searchKeys.map { "(\($0) CONTAINS[cd] %@)" }.joined(separator: " OR ")
    }
}

protocol ListObject: NSManagedObject, Searchable, Identifiable where ID == UUID? {
    
}
