//
//  DataProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData

protocol DataProvider: AnyObject {
    
    associatedtype Object: NSManagedObject
    typealias AddAction = (Object) -> Void
    typealias DeleteAction = (Bool) -> Void
    
    var persistentContainer: PersistentContainer { get }
    
    
}
