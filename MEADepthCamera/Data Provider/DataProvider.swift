//
//  DataProvider.swift
//  MEADepthCamera
//
//  Created by Will on 9/1/21.
//

import CoreData

protocol DataProvider: AnyObject {
    
    associatedtype Entity: NSManagedObject
    
    var persistentContainer: PersistentContainer { get }
    
    
}
