//
//  Recording+CoreDataClass.swift
//  MEADepthCamera
//
//  Created by Will on 8/12/21.
//
//

import CoreData
import AVFoundation

@objc(Recording)
public class Recording: NSManagedObject {
    
    public override func awakeFromFetch() {
        super.awakeFromFetch()
        //folderURL = useCase?.folderURL?.appendingPathComponent(name!)
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Documents directory.")
        }
        folderURL = docsURL.appendingPathComponent(name!)
    }
    
    func addFiles(_ newFiles: [OutputType: URL]) {
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
    
    /// Loads the video assets for the recording.
    ///
    /// Calling this method sets the `totalFrames` property for this recording.
    func loadAssets() -> (video: AVAsset, depth: AVAsset)? {
        guard let videoFile = files?.first(where: { ($0 as? OutputFile)?.outputType == OutputType.video.rawValue }) as? OutputFile,
              let depthFile = files?.first(where: { ($0 as? OutputFile)?.outputType == OutputType.depth.rawValue }) as? OutputFile,
              let videoURL = videoFile.fileURL,
              let depthURL = depthFile.fileURL else {
            print("Failed to access saved files")
            return nil
        }
        
        if FileManager.default.fileExists(atPath: videoURL.path) {
            totalFrames = Int64(getNumberOfFrames(videoURL))
        } else {
            print("File does not exist at specified URL: \(videoURL.path)")
            return nil
        }
        let videoAsset = AVAsset(url: videoURL)
        let depthAsset = AVAsset(url: depthURL)
        return (videoAsset, depthAsset)
    }
}

// MARK: Text Formatters
extension Recording {
    
    var isProcessedText: String {
        return isProcessed ? "Processed" : "Not Processed"
    }
    
    var durationText: String {
        return String(duration)
    }
    
    var filesCountText: String {
        switch filesCount {
        case 1:
            return String(filesCount) + " File"
        default:
            return String(filesCount) + " Files"
        }
    }
}
