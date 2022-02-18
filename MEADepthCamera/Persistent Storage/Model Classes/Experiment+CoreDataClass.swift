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
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
    
}

