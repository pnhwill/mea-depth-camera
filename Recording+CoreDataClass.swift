//
//  Recording+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 8/12/21.
//
//

import Foundation
import CoreData

@objc(Recording)
public class Recording: NSManagedObject {

    public override func awakeFromFetch() {
        super.awakeFromFetch()
        folderURL = useCase?.folderURL?.appendingPathComponent(name!)
    }
    
}