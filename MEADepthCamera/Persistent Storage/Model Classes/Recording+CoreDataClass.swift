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
        //folderURL = useCase?.folderURL?.appendingPathComponent(name!)
    }
    
    func addFiles(newFiles: [OutputType: URL]) {
        guard let context = managedObjectContext else { return }
        for file in newFiles {
            let newFile = OutputFile(context: context)
            newFile.outputType = file.key.rawValue
            newFile.fileName = file.value.lastPathComponent
            newFile.id = UUID()
            newFile.fileURL = file.value
            newFile.recording = self
            self.addToFiles(newFile)
        }
    }
    
}
