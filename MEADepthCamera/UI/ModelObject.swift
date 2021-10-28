//
//  ModelObject.swift
//  MEADepthCamera
//
//  Created by William Harrington on 10/15/21.
//

import UIKit
import CoreData

/// Protocol to which all objects from the Core Data model conform to interface with the UI.
protocol ModelObject: AnyObject {
    
    var id: UUID? { get set }
    
}

