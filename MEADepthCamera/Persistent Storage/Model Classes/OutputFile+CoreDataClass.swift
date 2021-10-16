//
//  OutputFile+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 8/12/21.
//
//

import Foundation
import CoreData

@objc(OutputFile)
public class OutputFile: NSManagedObject {

    public override func awakeFromFetch() {
        super.awakeFromFetch()
        fileURL = recording?.folderURL?.appendingPathComponent(fileName!)
    }
    
}

extension OutputFile: ModelObject {
    static func generateListContentConfiguration() -> ListContentConfiguration {
        return ListContentConfiguration(titleText: "", bodyText: [], buttonConfigurations: [])
    }
}
